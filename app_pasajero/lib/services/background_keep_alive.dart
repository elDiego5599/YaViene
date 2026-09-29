import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart'
    show debugPrint, kIsWeb, visibleForTesting;
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Mantiene el proceso vivo con la app en segundo plano. Sin esto, Android
/// suspende la app al salir de ella: el socket de posiciones muere a los
/// ~15 s (el servidor deja de recibir el ping) y los avisos de bus nunca
/// llegan. Con el servicio en primer plano el proceso sigue corriendo, el
/// socket sigue conectado y las notificaciones de proximidad disparan.
class BackgroundKeepAlive {
  static const _channelId = 'ya_viene_tracking';

  static bool _configured = false;

  /// Inicia el servicio (idempotente). Solo aplica en Android: en iOS el
  /// sistema operativo no permite ejecución continua y el aviso depende de
  /// la app abierta. Solo se llama con un aviso armado: sin avisos no hay
  /// nada que seguir en el fondo.
  static Future<void> start() async {
    if (!_isAndroid) return;
    final service = FlutterBackgroundService();
    try {
      if (!_configured) {
        await _ensureNotificationChannel();
        await service.configure(
          androidConfiguration: AndroidConfiguration(
            onStart: _onStart,
            autoStart: false,
            autoStartOnBoot: false,
            isForegroundMode: true,
            foregroundServiceTypes: const [AndroidForegroundType.dataSync],
            notificationChannelId: _channelId,
            initialNotificationTitle: 'Ya Viene',
            initialNotificationContent: 'Seguimiento de buses en segundo plano',
            foregroundServiceNotificationId: 8887,
          ),
          iosConfiguration: IosConfiguration(autoStart: false),
        );
        _configured = true;
      }
      if (await service.isRunning()) return;
      await service.startService();
    } catch (error) {
      // El mapa y las alertas locales siguen funcionando si el SO bloquea el
      // foreground service; un siguiente intento podrá reconfigurarlo.
      _configured = false;
      debugPrint('seguimiento en segundo plano no disponible: $error');
    }
  }

  /// Android 8+ exige que el canal exista antes de arrancar el servicio.
  static Future<void> _ensureNotificationChannel() async {
    final plugin = FlutterLocalNotificationsPlugin();
    await plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );
    await plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelId,
            'Seguimiento de buses',
            description:
                'Mantiene el seguimiento de buses activo en segundo plano',
            importance: Importance.low,
          ),
        );
  }

  /// Detiene el servicio (si está corriendo).
  static Future<void> stop() async {
    if (!_isAndroid) return;
    try {
      final service = FlutterBackgroundService();
      if (await service.isRunning()) {
        service.invoke('stopService');
      }
    } catch (error) {
      debugPrint('no se pudo detener el seguimiento en segundo plano: $error');
    }
  }

  /// Le dice al servicio que la app sigue viva. Si el servicio ya no corre
  /// (se paró solo porque las señales se retrasaron), lo vuelve a encender:
  /// quien late es la app, y la app solo late con avisos armados.
  static Future<void> latido() async {
    if (!_isAndroid) return;
    try {
      final service = FlutterBackgroundService();
      if (await service.isRunning()) {
        service.invoke('latido');
      } else {
        await start();
      }
    } catch (error) {
      debugPrint('no se pudo avisar al seguimiento en segundo plano: $error');
    }
  }

  static bool get _isAndroid => !kIsWeb && Platform.isAndroid;
}

/// Cuánto espera el servicio una señal de la app antes de pararse solo:
/// tres latidos (`cadaLatido`, 20 s) y un margen.
const sinLatidoMaximo = Duration(seconds: 65);

/// Callback del servicio: corre en un aislado propio y mantiene vivo el
/// proceso; un timer liviano evita que el aislado del servicio muera.
@pragma('vm:entry-point')
Future<void> _onStart(ServiceInstance service) => atenderServicio(service);

/// Lo que hace el servicio en su aislado.
///
/// El plugin revive el servicio con su perro guardián cada vez que el
/// sistema lo para sin un `stopService` explícito; también al quitar la app
/// de recientes. El servicio renacido corre sin la app —sin socket y sin
/// avisos—, con la notificación fija puesta y nada que seguir. Por eso
/// espera las señales de vida de la app, y si en [sinLatidoMaximo] no llega
/// ninguna se para él mismo con `stopSelf`: esa es la parada explícita que
/// el perro guardián respeta (auditoría 2026-09, H1).
@visibleForTesting
Future<void> atenderServicio(ServiceInstance service) async {
  Timer? refresco;
  Timer? plazo;
  void parar() {
    refresco?.cancel();
    plazo?.cancel();
    service.stopSelf();
  }

  void esperarLatido() {
    plazo?.cancel();
    plazo = Timer(sinLatidoMaximo, parar);
  }

  service.on('stopService').listen((_) => parar());
  service.on('latido').listen((_) => esperarLatido());
  esperarLatido();
  refresco = Timer.periodic(const Duration(seconds: 60), (_) async {
    if (service is AndroidServiceInstance) {
      await service.setForegroundNotificationInfo(
        title: 'Ya Viene',
        content: 'Seguimiento de buses en segundo plano',
      );
    }
  });
}

/// El servicio de fondo visto desde la app (inyectable en tests). Quien
/// decide cuándo encenderlo es `seguimientoSegundoPlanoProvider`.
abstract class ServicioDeFondo {
  Future<void> encender();
  Future<void> apagar();
  Future<void> latido();
}

class _ServicioAndroid implements ServicioDeFondo {
  const _ServicioAndroid();

  @override
  Future<void> encender() => BackgroundKeepAlive.start();

  @override
  Future<void> apagar() => BackgroundKeepAlive.stop();

  @override
  Future<void> latido() => BackgroundKeepAlive.latido();
}

final servicioDeFondoProvider =
    Provider<ServicioDeFondo>((ref) => const _ServicioAndroid());
