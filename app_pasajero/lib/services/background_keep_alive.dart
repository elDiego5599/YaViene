import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

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
  /// la app abierta.
  static Future<void> start() async {
    if (!_isAndroid) return;
    final service = FlutterBackgroundService();
    if (!_configured) {
      _configured = true;
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
    }
    if (await service.isRunning()) return;
    await service.startService();
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
            description: 'Mantiene el seguimiento de buses activo en segundo plano',
            importance: Importance.low,
          ),
        );
  }

  /// Detiene el servicio (si está corriendo).
  static Future<void> stop() async {
    if (!_isAndroid) return;
    final service = FlutterBackgroundService();
    if (await service.isRunning()) {
      service.invoke('stopService');
    }
  }

  static bool get _isAndroid => !kIsWeb && Platform.isAndroid;
}

/// Callback del servicio: corre en un aislado propio y mantiene vivo el
/// proceso; un timer liviano evita que el aislado del servicio muera.
@pragma('vm:entry-point')
Future<void> _onStart(ServiceInstance service) async {
  if (service is AndroidServiceInstance) {
    service.on('stopService').listen((_) => service.stopSelf());
  }
  Timer.periodic(const Duration(seconds: 60), (_) async {
    if (service is AndroidServiceInstance) {
      await service.setForegroundNotificationInfo(
        title: 'Ya Viene',
        content: 'Seguimiento de buses en segundo plano',
      );
    }
  });
}
