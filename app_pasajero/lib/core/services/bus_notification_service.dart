import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../utils/bus_labels.dart';

/// Notificaciones locales de proximidad de buses (sin servidor).
///
/// Cada bus con alerta activa tiene su propio aviso (id estable por bus):
/// "Calle 72 - Uninorte - B-042 está cerca de ti · Está a 430 m de tu ubicación".
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
  static Future<void> notifyBusNear({
    required String busId,
    String? routeName,
    String? routeId,
    required int distanceMeters,
  }) async {
    try {
      await _plugin.show(
        id: _stableNotificationId(busId),
        title:
            '${routePlateLabel(busId: busId, routeName: routeName, routeId: routeId)} está cerca de ti',
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
    } catch (e, st) {
      debugPrint('notifyBusNear failed for $busId: $e\n$st');
      // El aviso falla blando: nunca debe tumbar el flujo del mapa.
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
