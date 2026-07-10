/// =============================================================================
/// BACKGROUND SERVICE CONFIG
///
/// Inicializa el servicio en primer plano para Android.
/// Esto garantiza que el SO no asigne una prioridad baja a nuestra app
/// cuando el conductor apaga la pantalla, manteniendo el ciclo GPS y MQTT vivos.
/// =============================================================================

import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';

Future<void> initializeBackgroundService() async {
  final service = FlutterBackgroundService();

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      // Punto de entrada cuando el servicio corre en background
      onStart: onBackgroundStart,
      
      // La notificación que se mostrará permanentemente en el celular
      autoStart: false,
      isForegroundMode: true,
      
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

/// Punto de entrada Aislado (Isolate) de Dart.
/// Aquí NO hay acceso a la UI ni a Riverpod global (se debe inicializar otro scope).
@pragma('vm:entry-point')
void onBackgroundStart(ServiceInstance service) async {
  // Solo se necesita para iOS en este paquete
  DartPluginRegistrant.ensureInitialized();

  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });

    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
  }

  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  // TODO: En este Isolate, inicializar Geolocator, OfflineBufferRepository y MQTT.
  // El código correrá continuamente aquí aunque la actividad principal sea destruida.
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  return true;
}
