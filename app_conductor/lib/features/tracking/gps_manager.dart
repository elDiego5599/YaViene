
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

    var status = await Permission.locationAlways.status;
    if (!status.isGranted) {
      await Permission.locationWhenInUse.request();
      status = await Permission.locationAlways.request();
      
      if (!status.isGranted) {
        _ref.read(trackingStateProvider.notifier).state = TrackingState.error;
        return;
      }
    }

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 0,
    );

    _ref.read(trackingStateProvider.notifier).state = TrackingState.tracking;
    await _offlineBuffer.init();

    _positionStream = Geolocator.getPositionStream(locationSettings: locationSettings)
        .listen((Position position) async {
      
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
