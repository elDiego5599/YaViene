/// =============================================================================
/// GPS MANAGER & ANTI-FRAUDE
///
/// Lógica central de recolección de ubicación de la App Conductor.
///
/// Responsabilidades:
///   1. Configurar Geolocator para alta precisión (necesaria en buses).
///   2. Leer la bandera nativa `isMocked` de cada punto GPS.
///   3. Si es Mocked (Fake GPS) → Detiene la emisión, notifica fraude.
///   4. Si es Legítima → Guarda en Buffer Offline y notifica a MQTT.
/// =============================================================================

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:logger/logger.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:ya_viene_core/ya_viene_core.dart';

import '../../core/offline/offline_buffer_repository.dart';

enum TrackingState {
  stopped,
  tracking,
  fraudDetected, // GPS Falso detectado
  error,
}

final trackingStateProvider = StateProvider<TrackingState>((ref) => TrackingState.stopped);

final gpsManagerProvider = Provider<GpsManager>((ref) {
  return GpsManager(ref);
});

class GpsManager {
  final Ref _ref;
  final Logger _logger = Logger();
  final OfflineBufferRepository _offlineBuffer = OfflineBufferRepository();
  
  StreamSubscription<Position>? _positionStream;

  GpsManager(this._ref);

  Future<void> startTracking({
    required String empresaId,
    required String busId,
    required String routeId,
  }) async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _ref.read(trackingStateProvider.notifier).state = TrackingState.error;
      return;
    }

    // Requiere pedir explicitly la ubicación en background (Always)
    // para poder usar el foregroundServiceType="location" en Android 14+
    var status = await Permission.locationAlways.status;
    if (!status.isGranted) {
      // Pedir WhenInUse primero (obligatorio en Android 11+)
      await Permission.locationWhenInUse.request();
      status = await Permission.locationAlways.request();
      
      if (!status.isGranted) {
        _ref.read(trackingStateProvider.notifier).state = TrackingState.error;
        return;
      }
    }

    // Configuración para Vehículos (alta precisión, actualizaciones frecuentes)
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 0, // Emitir siempre que haya cambio, sin importar distancia
    );

    _ref.read(trackingStateProvider.notifier).state = TrackingState.tracking;
    await _offlineBuffer.init();

    _positionStream = Geolocator.getPositionStream(locationSettings: locationSettings)
        .listen((Position position) async {
      
      // ── POLÍTICA ANTI-FRAUDE (Zero Trust) ──────────────────────────────────
      if (position.isMocked) {
        _logger.w('FRAUDE DETECTADO: El conductor $busId está usando Fake GPS.');
        stopTracking();
        _ref.read(trackingStateProvider.notifier).state = TrackingState.fraudDetected;
        // TODO: Enviar bandera roja por MQTT al backend administrativo
        return;
      }

      // Convertir a modelo de dominio
      final busPosition = BusPosition(
        busId: busId,
        routeId: routeId,
        lat: position.latitude,
        lon: position.longitude,
        heading: position.heading,
        speedKmh: position.speed * 3.6, // m/s a km/h
        timestamp: position.timestamp,
        isGhostBus: false,
      );

      // ── RESILIENCIA OFFLINE ────────────────────────────────────────────────
      // Siempre se guarda en local primero.
      await _offlineBuffer.savePosition(busPosition);

      // TODO: Intentar publicar por MQTT
      // Si MQTT publica con éxito: _offlineBuffer.clearPendingPositions();
      // Si MQTT falla (no hay red): No se hace nada, el buffer se acumulará.
      
      _logger.i('GPS Validado: $busId en ${position.latitude}, ${position.longitude}');
    });
  }

  void stopTracking() {
    _positionStream?.cancel();
    _positionStream = null;
    if (_ref.read(trackingStateProvider.notifier).state == TrackingState.tracking) {
      _ref.read(trackingStateProvider.notifier).state = TrackingState.stopped;
    }
  }
}
