import 'dart:async';

import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import 'tracking_engine.dart';

enum TrackingState { stopped, tracking, fraudDetected, error }

final trackingStateProvider = StateProvider<TrackingState>(
  (ref) => TrackingState.stopped,
);

final gpsManagerProvider = Provider<GpsManager>((ref) {
  final manager = GpsManager(ref);
  ref.onDispose(manager.dispose);
  return manager;
});

class GpsManager {
  final Ref _ref;
  final FlutterBackgroundService _service = FlutterBackgroundService();
  StreamSubscription<Map<String, dynamic>?>? _stateSubscription;

  GpsManager(this._ref) {
    _stateSubscription = _service.on('trackingState').listen((data) {
      final state = data?['state'] as String?;
      if (state == null) return;
      _ref.read(trackingStateProvider.notifier).state = switch (state) {
        'tracking' => TrackingState.tracking,
        'fraudDetected' => TrackingState.fraudDetected,
        'error' => TrackingState.error,
        _ => TrackingState.stopped,
      };
    });
  }

  Future<void> startTracking({
    required String empresaId,
    required String busId,
    required String routeId,
    required String phoneNumber,
    required String jwtToken,
  }) async {
    if (!await _hasLocationAccess()) {
      _ref.read(trackingStateProvider.notifier).state = TrackingState.error;
      return;
    }

    final config = TrackingConfig(
      empresaId: empresaId,
      busId: busId,
      routeId: routeId,
      phoneNumber: phoneNumber,
      jwtToken: jwtToken,
    );

    final running = await _service.isRunning();
    if (!running && !await _service.startService()) {
      _ref.read(trackingStateProvider.notifier).state = TrackingState.error;
      return;
    }

    _service.invoke('startTracking', config.toJson());
    _ref.read(trackingStateProvider.notifier).state = TrackingState.tracking;
  }

  void stopTracking() {
    _service.invoke('stopTracking');
    _ref.read(trackingStateProvider.notifier).state = TrackingState.stopped;
  }

  Future<bool> _hasLocationAccess() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;

    var status = await Permission.locationAlways.status;
    if (status.isGranted) return true;

    await Permission.locationWhenInUse.request();
    status = await Permission.locationAlways.request();
    return status.isGranted;
  }

  void dispose() {
    _stateSubscription?.cancel();
    _stateSubscription = null;
  }
}
