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

final trackingStateProvider =
    StateProvider<TrackingState>((ref) => TrackingState.stopped);

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
  bool _isSyncing = false;
  int? _nextSequence;

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

    await _offlineBuffer.init();
    _nextSequence ??= await _offlineBuffer.nextSequence();

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

    _positionStream =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
            (Position position) async {
      _positionCount++;

      if (position.isMocked) {
        _logger
            .w('FRAUDE DETECTADO: El conductor $busId está usando Fake GPS.');
        stopTracking();
        _ref.read(trackingStateProvider.notifier).state =
            TrackingState.fraudDetected;
        return;
      }

      final sequence = _nextSequence!;
      _nextSequence = sequence + 1;
      final capturedAt = position.timestamp.millisecondsSinceEpoch;
      final busPosition = BusPosition(
          busId: busId,
          routeId: routeId,
          lat: position.latitude,
          lon: position.longitude,
          heading: position.heading,
          speedKmh: position.speed * 3.6,
          timestamp: position.timestamp,
          isGhostBus: false,
          sequence: sequence);

      int? pendingId;
      try {
        pendingId =
            await _offlineBuffer.savePosition(busPosition, inFlight: true);
        final ack = await _mqttService.publishPosition(
          lat: position.latitude,
          lon: position.longitude,
          heading: position.heading,
          speedKmh: position.speed * 3.6,
          capturedAt: capturedAt,
          sequence: sequence,
        );
        if (ack == null) {
          await _offlineBuffer
              .markPending([pendingId], error: 'No ACK received');
        } else {
          if (!ack.accepted) {
            _logger
                .w('Posición $sequence rechazada por backend: ${ack.reason}');
          }
          await _offlineBuffer.deletePositions([pendingId]);
        }
      } catch (error) {
        if (pendingId != null) {
          await _offlineBuffer
              .markPending([pendingId], error: error.toString());
        }
        _logger.w('Error guardando/publicando posición $sequence: $error');
      }
    }, onError: (error) {
      _logger.w('Error en stream GPS: $error');
    });

    _healthTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!_mqttService.isConnected || _positionCount == 0) {
        _logger.w('HEALTH: MQTT caído o sin posiciones en 15s — reconectando');
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
      if (_isSyncing || !_mqttService.isConnected) return;

      _isSyncing = true;
      try {
        await _offlineBuffer.syncPendingPositions(
          (batch) async {
            final resolved = <int>{};
            for (final pending in batch) {
              final pos = pending.position;
              final sequence = pos.sequence;
              if (sequence == null || sequence < 1) {
                resolved.add(pending.id);
                continue;
              }

              final ack = await _mqttService.publishPosition(
                lat: pos.lat,
                lon: pos.lon,
                heading: pos.heading,
                speedKmh: pos.speedKmh,
                capturedAt: pos.timestamp.millisecondsSinceEpoch,
                sequence: sequence,
              );
              if (ack != null) {
                resolved.add(pending.id);
                if (!ack.accepted) {
                  _logger.w(
                      'Replay $sequence rechazado por backend: ${ack.reason}');
                }
              }
            }
            return resolved;
          },
        );
      } catch (_) {
      } finally {
        _isSyncing = false;
      }
    });
  }

  Future<void> _initiateReconnect({
    required String empresaId,
    required String busId,
    required String routeId,
    required String phoneNumber,
    required String jwtToken,
  }) async {
    if (_mqttService.isConnected) return;
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
    if (_ref.read(trackingStateProvider.notifier).state ==
        TrackingState.tracking) {
      _ref.read(trackingStateProvider.notifier).state = TrackingState.stopped;
    }
  }
}
