
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:logger/logger.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:ya_viene_core/ya_viene_core.dart';

import '../../core/offline/offline_buffer_repository.dart';
import 'mqtt_service.dart';

enum TrackingState {
  stopped,
  tracking,
  fraudDetected,
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
  final MqttService _mqttService = MqttService();

  StreamSubscription<Position>? _positionStream;
  Timer? _healthTimer;
  Timer? _syncTimer;
  int _positionCount = 0;

  GpsManager(this._ref);

  Future<void> startTracking({
    required String empresaId,
    required String busId,
    required String routeId,
    required String phoneNumber,
    required String jwtToken,
  }) async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _ref.read(trackingStateProvider.notifier).state = TrackingState.error;
      return;
    }

    var status = await Permission.locationAlways.status;
    if (!status.isGranted) {
      await Permission.locationWhenInUse.request();
      status = await Permission.locationAlways.request();

      if (!status.isGranted) {
        _ref.read(trackingStateProvider.notifier).state = TrackingState.error;
        return;
      }
    }

    await _mqttService.connect(
      empresaId: empresaId,
      busId: busId,
      phoneNumber: phoneNumber,
      jwtToken: jwtToken,
    );

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 0,
    );

    _ref.read(trackingStateProvider.notifier).state = TrackingState.tracking;
    await _offlineBuffer.init();

    _positionStream = Geolocator.getPositionStream(locationSettings: locationSettings)
        .listen((Position position) async {
      _positionCount++;

      if (position.isMocked) {
        _logger.w('FRAUDE DETECTADO: El conductor $busId está usando Fake GPS.');
        stopTracking();
        _ref.read(trackingStateProvider.notifier).state = TrackingState.fraudDetected;
        return;
      }

      final busPosition = BusPosition(
        busId: busId,
        routeId: routeId,
        lat: position.latitude,
        lon: position.longitude,
        heading: position.heading,
        speedKmh: position.speed * 3.6,
        timestamp: position.timestamp,
        isGhostBus: false,
      );

      await _offlineBuffer.savePosition(busPosition);

      try {
        _mqttService.publishPosition(
          lat: position.latitude,
          lon: position.longitude,
          heading: position.heading,
          speedKmh: position.speed * 3.6,
        );
      } catch (_) {}

    }, onError: (error) {
      _logger.w('Error en stream GPS: $error');
    });

    _healthTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (_positionCount == 0) {
        _logger.w('HEALTH: Sin posiciones en los últimos 15s — reconectando MQTT');
        _initiateReconnect(
          empresaId: empresaId,
          busId: busId,
          routeId: routeId,
          phoneNumber: phoneNumber,
          jwtToken: jwtToken,
        );
      }
      _positionCount = 0;
    });

    _syncTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      if (!_mqttService.isConnected) return;
      await _offlineBuffer.syncPendingPositions(
        (batch) async {
          for (final pos in batch) {
            _mqttService.publishPosition(
              lat: pos.lat,
              lon: pos.lon,
              heading: pos.heading,
              speedKmh: pos.speedKmh,
            );
          }
          return true;
        },
      );
    });
  }

  Future<void> _initiateReconnect({
    required String empresaId,
    required String busId,
    required String routeId,
    required String phoneNumber,
    required String jwtToken,
  }) async {
    _logger.i('Intentando reconexión MQTT...');
    await _mqttService.connect(
      empresaId: empresaId,
      busId: busId,
      phoneNumber: phoneNumber,
      jwtToken: jwtToken,
    );
  }

  void stopTracking() {
    _healthTimer?.cancel();
    _healthTimer = null;
    _syncTimer?.cancel();
    _syncTimer = null;
    _positionStream?.cancel();
    _positionStream = null;
    _mqttService.disconnect();
    if (_ref.read(trackingStateProvider.notifier).state == TrackingState.tracking) {
      _ref.read(trackingStateProvider.notifier).state = TrackingState.stopped;
    }
  }
}
