import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:logger/logger.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

import '../../core/offline/offline_buffer_repository.dart';
import 'mqtt_service.dart';

enum TrackingEngineState { stopped, tracking, fraudDetected, error }

class DriverTrackingStatus {
  final bool gpsActive;
  final bool mqttConnected;
  final bool ackHealthy;
  final int outboxPendingCount;
  final String? lastError;

  const DriverTrackingStatus({
    this.gpsActive = false,
    this.mqttConnected = false,
    this.ackHealthy = false,
    this.outboxPendingCount = 0,
    this.lastError,
  });

  bool get isFullyTransmitting => gpsActive && mqttConnected && ackHealthy;
}

class TrackingConfig {
  final String empresaId;
  final String busId;
  final String routeId;
  final String phoneNumber;
  final String jwtToken;

  const TrackingConfig({
    required this.empresaId,
    required this.busId,
    required this.routeId,
    required this.phoneNumber,
    required this.jwtToken,
  });

  factory TrackingConfig.fromJson(Map<String, dynamic> json) {
    return TrackingConfig(
      empresaId: json['empresaId'] as String,
      busId: json['busId'] as String,
      routeId: json['routeId'] as String,
      phoneNumber: json['phoneNumber'] as String,
      jwtToken: json['jwtToken'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'empresaId': empresaId,
        'busId': busId,
        'routeId': routeId,
        'phoneNumber': phoneNumber,
        'jwtToken': jwtToken,
      };

  String get key => '$empresaId|$busId|$routeId|$phoneNumber|$jwtToken';
}

class TrackingEngine {
  final Logger _logger = Logger();
  final OfflineBufferRepository _offlineBuffer = OfflineBufferRepository();
  final MqttService _mqttService = MqttService();

  StreamSubscription<Position>? _positionStream;
  Timer? _healthTimer;
  Timer? _syncTimer;
  int? _nextSequence;
  bool _isSyncing = false;
  bool _running = false;
  void Function(TrackingEngineState state)? _onState;
  void Function(DriverTrackingStatus status)? _onStatus;
  bool _startInProgress = false;
  String? _activeConfigKey;

  Future<void> start(
    TrackingConfig config,
    void Function(TrackingEngineState state) onState, {
    void Function(DriverTrackingStatus status)? onStatus,
  }) async {
    if (_startInProgress) return;
    if (_running && _activeConfigKey == config.key) return;
    _startInProgress = true;
    await stop(emitStopped: false);
    _onState = onState;
    _onStatus = onStatus;
    _activeConfigKey = config.key;
    _running = true;

    try {
      await _offlineBuffer.init();
      _nextSequence = await _offlineBuffer.nextSequence();

      final mqttConnected = await _mqttService.connect(
        empresaId: config.empresaId,
        busId: config.busId,
        phoneNumber: config.phoneNumber,
        jwtToken: config.jwtToken,
      );

      final locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 2,
        intervalDuration: const Duration(seconds: 1),
      );

      _positionStream = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen(
        (position) => _handlePosition(config, position),
        onError: (error) => _logger.w('Error en stream GPS: $error'),
      );

      _healthTimer = Timer.periodic(const Duration(seconds: 15), (_) {
        if (!_mqttService.isConnected) {
          _logger.w('HEALTH: MQTT caído — reconectando');
          _initiateReconnect(config);
        }
      });

      _syncTimer = Timer.periodic(const Duration(seconds: 10), (_) {
        _syncPending();
      });
      _emitStatus(
        gpsActive: true,
        mqttConnected: mqttConnected,
      );
      _onState?.call(TrackingEngineState.tracking);
    } catch (error) {
      _logger.e('Error iniciando tracking: $error');
      _running = false;
      _emitStatus(lastError: error.toString());
      _onState?.call(TrackingEngineState.error);
    } finally {
      _startInProgress = false;
    }
  }

  Future<void> _handlePosition(TrackingConfig config, Position position) async {
    if (!_running) return;

    if (position.isMocked) {
      _logger.w('FRAUDE DETECTADO: ${config.busId} usa Fake GPS');
      _onState?.call(TrackingEngineState.fraudDetected);
      await stop(emitStopped: false);
      return;
    }

    final sequence = _nextSequence;
    if (sequence == null) {
      _logger.e('Sequence storage is not initialized');
      _emitStatus(lastError: 'Sequence storage is not initialized');
      return;
    }
    _nextSequence = sequence + 1;
    final capturedAt = position.timestamp.millisecondsSinceEpoch;
    final busPosition = BusPositionData(
      lat: position.latitude,
      lon: position.longitude,
      heading: position.heading,
      speedKmh: position.speed * 3.6,
      capturedAt: capturedAt,
      sequence: sequence,
    );

    int? pendingId;
    try {
      pendingId = await _offlineBuffer.savePosition(
        busPosition.toModel(config),
        inFlight: true,
      );
      final ack = await _mqttService.publishPosition(
        lat: busPosition.lat,
        lon: busPosition.lon,
        heading: busPosition.heading,
        speedKmh: busPosition.speedKmh,
        capturedAt: capturedAt,
        sequence: sequence,
      );

      if (ack == null) {
        await _offlineBuffer.markPending([pendingId], error: 'No ACK received');
        _emitStatus(ackHealthy: false);
      } else {
        if (!ack.accepted) {
          _logger.w('Posición $sequence rechazada: ${ack.reason}');
        }
        await _offlineBuffer.deletePositions([pendingId]);
        _emitStatus(
          ackHealthy: ack.accepted,
          outboxPendingCount: await _offlineBuffer.pendingCount(),
        );
      }
    } catch (error) {
      if (pendingId != null) {
        await _offlineBuffer.markPending([pendingId], error: error.toString());
      }
      _logger.w('Error procesando posición $sequence: $error');
      _emitStatus(lastError: error.toString());
    }
  }

  Future<void> _syncPending() async {
    if (!_running || _isSyncing || !_mqttService.isConnected) return;
    _isSyncing = true;
    try {
      await _offlineBuffer.syncPendingPositions((batch) async {
        final resolved = <int>{};
        for (final pending in batch) {
          final position = pending.position;
          final sequence = position.sequence;
          if (sequence == null || sequence < 1) {
            resolved.add(pending.id);
            continue;
          }

          final ack = await _mqttService.publishPosition(
            lat: position.lat,
            lon: position.lon,
            heading: position.heading,
            speedKmh: position.speedKmh,
            capturedAt: position.timestamp.millisecondsSinceEpoch,
            sequence: sequence,
          );
          if (ack != null) resolved.add(pending.id);
        }
        return resolved;
      });
    } catch (error) {
      _logger.w('Error sincronizando outbox: $error');
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _initiateReconnect(TrackingConfig config) async {
    if (!_running || _mqttService.isConnected) return;
    final connected = await _mqttService.connect(
      empresaId: config.empresaId,
      busId: config.busId,
      phoneNumber: config.phoneNumber,
      jwtToken: config.jwtToken,
    );
    _emitStatus(mqttConnected: connected, ackHealthy: false);
  }

  Future<void> stop({bool emitStopped = true}) async {
    _running = false;
    _healthTimer?.cancel();
    _healthTimer = null;
    _syncTimer?.cancel();
    _syncTimer = null;
    await _positionStream?.cancel();
    _positionStream = null;
    _mqttService.disconnect();
    _activeConfigKey = null;
    _emitStatus();
    if (emitStopped) _onState?.call(TrackingEngineState.stopped);
  }

  void _emitStatus({
    bool? gpsActive,
    bool? mqttConnected,
    bool? ackHealthy,
    int? outboxPendingCount,
    String? lastError,
  }) {
    _onStatus?.call(DriverTrackingStatus(
      gpsActive: gpsActive ?? _running,
      mqttConnected: mqttConnected ?? _mqttService.isConnected,
      ackHealthy: ackHealthy ?? false,
      outboxPendingCount: outboxPendingCount ?? 0,
      lastError: lastError,
    ));
  }
}

class BusPositionData {
  final double lat;
  final double lon;
  final double heading;
  final double speedKmh;
  final int capturedAt;
  final int sequence;

  const BusPositionData({
    required this.lat,
    required this.lon,
    required this.heading,
    required this.speedKmh,
    required this.capturedAt,
    required this.sequence,
  });

  BusPosition toModel(TrackingConfig config) => BusPosition(
        busId: config.busId,
        routeId: config.routeId,
        lat: lat,
        lon: lon,
        heading: heading,
        speedKmh: speedKmh,
        timestamp: DateTime.fromMillisecondsSinceEpoch(capturedAt),
        isGhostBus: false,
        sequence: sequence,
      );
}
