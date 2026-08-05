import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'tracking_engine.dart';

Future<void> initializeBackgroundService() async {
  const notificationChannel = AndroidNotificationChannel(
    'yaviene_conductor_channel',
    'Ya Viene Conductor',
    description: 'Estado de la transmisión GPS del conductor.',
    importance: Importance.low,
  );
  final notifications = FlutterLocalNotificationsPlugin();
  await notifications
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.requestNotificationsPermission();
  await notifications
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(notificationChannel);

  final service = FlutterBackgroundService();

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onBackgroundStart,
      autoStart: false,
      autoStartOnBoot: false,
      isForegroundMode: true,
      foregroundServiceTypes: [AndroidForegroundType.location],
      notificationChannelId: 'yaviene_conductor_channel',
      initialNotificationTitle: 'Ya Viene',
      initialNotificationContent: 'Transmitiendo ubicación del bus...',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: onBackgroundStart,
      onBackground: onIosBackground,
    ),
  );
}

@pragma('vm:entry-point')
void onBackgroundStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  final engine = TrackingEngine();

  void emitState(TrackingEngineState state) {
    service.invoke('trackingState', {'state': state.name});
  }

  void emitStatus(DriverTrackingStatus status) {
    service.invoke('trackingStatus', {
      'gpsActive': status.gpsActive,
      'mqttConnected': status.mqttConnected,
      'ackHealthy': status.ackHealthy,
      'outboxPendingCount': status.outboxPendingCount,
      'lastError': status.lastError,
    });
  }

  service.on('startTracking').listen((event) async {
    if (event == null) return;
    try {
      await engine.start(
        TrackingConfig.fromJson(event),
        emitState,
        onStatus: emitStatus,
      );
    } catch (_) {
      emitState(TrackingEngineState.error);
    }
  });

  service.on('stopTracking').listen((_) async {
    await engine.stop();
    await service.stopSelf();
  });

  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });

    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
  }

  service.on('stopService').listen((event) {
    engine.stop();
    service.stopSelf();
  });
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  return true;
}
