import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../utils/bus_labels.dart';
import '../utils/distancia.dart';

/// Notificaciones locales de proximidad de buses (sin servidor).
///
/// Cada bus con alerta activa tiene su propio aviso (id estable por bus):
/// título "Calle 72 - Uninorte - WGV705 está cerca de ti" y cuerpo
/// "Está a 430 m de tu ubicación".
class BusNotificationService {
  BusNotificationService._();

  static const _channelId = 'bus_alerts';
  static const _channelName = 'Alertas de buses';

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      // En iOS, DarwinInitializationSettings pide los permisos al
      // inicializar salvo que se le diga que no, así que el cuadro de
      // "Ya Viene quiere enviarte notificaciones" salía nada más abrir la
      // app —encima del arranque, antes de que nadie hubiera visto para
      // qué sirven—. Justo lo que la guía de Apple dice no hacer, y lo
      // contrario de lo que promete `requestPermission` más abajo. Se
      // piden ahí, cuando el usuario activa su primer aviso.
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _plugin.initialize(settings: settings);
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: 'Avisos cuando un bus seleccionado se acerque a ti',
        importance: Importance.high,
      ),
    );
  }

  static Future<bool> areNotificationsEnabled() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      return await android.areNotificationsEnabled() ?? false;
    }
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) return (await ios.checkPermissions())?.isEnabled ?? false;
    return true;
  }

  /// Si un aviso se vería ahora: el permiso general dado y, en Android, el
  /// canal «Alertas de buses» sin apagar. Se puede apagar solo esa categoría
  /// en Ajustes con el permiso general intacto, y entonces Android descarta
  /// el aviso igual de callado.
  static Future<bool> puedeAvisar() async {
    if (!await areNotificationsEnabled()) return false;
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return true;
    try {
      final canales = await android.getNotificationChannels();
      for (final canal in canales ?? const <AndroidNotificationChannel>[]) {
        if (canal.id == _channelId) return canal.importance != Importance.none;
      }
    } catch (e) {
      // Sin la lista de canales no se sabe; el permiso general ya dijo que sí.
      debugPrint('no se pudo leer el canal de avisos: $e');
    }
    return true;
  }

  /// Pide el permiso de notificaciones (Android 13+) en el momento en que el
  /// usuario activa la alerta, no al abrir la app.
  static Future<bool> requestPermission() async {
    if (await areNotificationsEnabled()) return true;
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      return await ios.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }
    return false;
  }

  /// Notificación diferenciada por bus: id hash estable entre ejecuciones.
  ///
  /// Devuelve si el aviso llegó a mostrarse; si no, quien llama no lo da
  /// por enviado: el bus sigue en la lista de avisos activos y el barrido
  /// lo reintenta.
  ///
  /// Con el permiso revocado desde Ajustes, `show` no falla: ni Android ni
  /// iOS lanzan un error, el sistema descarta la notificación callado. Por
  /// eso se pregunta antes ([puedeAvisar]) en vez de fiarse de que `show`
  /// terminara bien (auditoría 2026-09, H2).
  static Future<bool> notifyBusNear({
    required String busId,
    String? routeName,
    String? routeId,
    required int distanceMeters,
  }) async {
    final etiqueta = routePlateLabel(
      busId: busId,
      routeName: routeName,
      routeId: routeId,
    );
    try {
      if (!await puedeAvisar()) return false;
      await _plugin.show(
        id: _stableNotificationId(busId),
        title: '$etiqueta está cerca de ti',
        body: 'Está a ${distanciaAviso(distanceMeters)} de tu ubicación',
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            importance: Importance.high,
            priority: Priority.high,
            playSound: true,
          ),
          iOS: DarwinNotificationDetails(),
        ),
      );
      return true;
    } catch (e, st) {
      debugPrint('notifyBusNear failed for $busId: $e\n$st');
      // El aviso falla blando: nunca debe tumbar el flujo del mapa. Pero el
      // fallo se cuenta, para que el aviso siga armado y se reintente.
      return false;
    }
  }
}

int _stableNotificationId(String value) {
  // String.hashCode no garantiza el mismo valor entre procesos; FNV-1a sí
  // permite reemplazar la notificación del mismo bus tras reabrir la app.
  var hash = 0x811c9dc5;
  for (final unit in value.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0x7fffffff;
  }
  return hash == 0 ? 1 : hash;
}
