import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Notificaciones locales de proximidad de buses (sin servidor).
///
/// Cada bus con alerta activa tiene su propio aviso (id estable por bus):
/// "SQA-101 está cerca de ti · Está a 430 m de tu ubicación".
class BusNotificationService {
  BusNotificationService._();

  static const _channelId = 'bus_alerts';
  static const _channelName = 'Alertas de buses';

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await _plugin.initialize(settings: settings);
    final android = _plugin
        .resolvePlatformSpecificImplementation<
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
    final android = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    return await android?.areNotificationsEnabled() ?? true;
  }

  /// Pide el permiso de notificaciones (Android 13+) en el momento en que el
  /// usuario activa la alerta, no al abrir la app.
  static Future<bool> requestPermission() async {
    if (await areNotificationsEnabled()) return true;
    final android = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    final granted = await android?.requestNotificationsPermission();
    return granted ?? false;
  }

  /// Notificación diferenciada por bus: id = hash estable del busId.
  static Future<void> notifyBusNear({
    required String busId,
    required int distanceMeters,
  }) async {
    try {
      await _plugin.show(
        id: busId.hashCode & 0x7fffffff,
        title: '$busId está cerca de ti',
        body: 'Está a $distanceMeters m de tu ubicación',
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
    } catch (_) {
      // El aviso falla blando: nunca debe tumbar el flujo del mapa.
    }
  }
}
