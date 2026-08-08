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

final trackingStatusProvider = StateProvider<DriverTrackingStatus>(
  (ref) => const DriverTrackingStatus(),
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
  StreamSubscription<Map<String, dynamic>?>? _statusSubscription;

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
    _statusSubscription = _service.on('trackingStatus').listen((data) {
      if (data == null) return;
      _ref.read(trackingStatusProvider.notifier).state = DriverTrackingStatus(
        gpsActive: data['gpsActive'] as bool? ?? false,
        mqttConnected: data['mqttConnected'] as bool? ?? false,
        ackHealthy: data['ackHealthy'] as bool? ?? false,
        outboxPendingCount: (data['outboxPendingCount'] as num?)?.toInt() ?? 0,
        lastError: data['lastError'] as String?,
      );
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

    var status = await Permission.locationWhenInUse.status;
    if (!status.isGranted) {
      status = await Permission.locationWhenInUse.request();
    }
    if (!status.isGranted) return false;

    // "Todo el tiempo" solo se necesita para transmitir con la app en
    // segundo plano; con "Mientras se usa" alcanza para transmitir con la
    // app abierta. Se pide como best-effort, sin bloquear el arranque.
    if (!(await Permission.locationAlways.status).isGranted) {
      await Permission.locationAlways.request();
    }
    return true;
  }

  void dispose() {
    _stateSubscription?.cancel();
    _stateSubscription = null;
    _statusSubscription?.cancel();
    _statusSubscription = null;
  }
}
