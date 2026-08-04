import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:logger/logger.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

import '../../config.dart';

class PositionAck {
  final String sessionId;
  final int sequence;
  final bool accepted;
  final String? reason;

  const PositionAck({
    required this.sessionId,
    required this.sequence,
    required this.accepted,
    this.reason,
  });
}

class MqttService {
  final Logger _logger = Logger();
  MqttServerClient? _client;
  bool _connected = false;

  String? _empresaId;
  String? _busId;
  String? _host;
  String? _ackTopic;
  String? _sessionId;
  StreamSubscription<List<MqttReceivedMessage<MqttMessage>>>?
      _updatesSubscription;
  final Map<int, Completer<PositionAck?>> _ackWaiters = {};

  Future<bool> connect({
    required String empresaId,
    required String busId,
    required String phoneNumber,
    required String jwtToken,
  }) async {
    disconnect();

    _empresaId = empresaId;
    _busId = busId;
    _sessionId = _readSessionId(jwtToken);

    final uri = Uri.parse(AppConfig.backendUrl);
    _host = uri.host;

    final clientId = 'conductor_${busId}_${Random().nextInt(999999)}';
    _client = MqttServerClient(_host!, clientId);
    _client!.port = AppConfig.mqttPort;
    _client!.keepAlivePeriod = 10;
    _client!.connectTimeoutPeriod = 5000;
    _client!.logging(on: false);
    _client!.autoReconnect = false;

    final connMsg = MqttConnectMessage()
        .withClientIdentifier(clientId)
        .authenticateAs(phoneNumber, jwtToken)
        .startClean();
    _client!.connectionMessage = connMsg;

    _client!.onConnected = () {
      _connected = true;
      _logger.i('MQTT conectado a $_host:${AppConfig.mqttPort}');
    };
    _client!.onDisconnected = () {
      if (_connected) {
        _connected = false;
        _completePendingAcks(null);
        _logger.w('MQTT desconectado');
      }
    };

    try {
      await _client!.connect();
      if (!_connected) return false;

      _ackTopic = 'empresa/$_empresaId/bus/$_busId/ack';
      _updatesSubscription = _client!.updates?.listen(_handleUpdates);
      _client!.subscribe(_ackTopic!, MqttQos.atLeastOnce);
      return true;
    } catch (e) {
      _logger.e('Error conectando MQTT: $e');
      _connected = false;
      return false;
    }
  }

  Future<PositionAck?> publishPosition({
    required double lat,
    required double lon,
    double? heading,
    double? speedKmh,
    required int capturedAt,
    required int sequence,
  }) async {
    if (!_connected ||
        _client == null ||
        _empresaId == null ||
        _busId == null) {
      return null;
    }

    final topic = 'empresa/$_empresaId/bus/$_busId/posicion';
    final payload = jsonEncode({
      'protocolVersion': 1,
      'lat': lat,
      'lon': lon,
      'heading': heading ?? 0.0,
      'speedKmh': speedKmh ?? 0.0,
      'capturedAt': capturedAt,
      'sequence': sequence,
    });

    final waiter = Completer<PositionAck?>();
    _ackWaiters[sequence] = waiter;
    try {
      final builder = MqttClientPayloadBuilder()..addString(payload);
      final bytes = builder.payload;
      if (bytes == null) {
        _ackWaiters.remove(sequence);
        return null;
      }

      _client!.publishMessage(topic, MqttQos.atLeastOnce, bytes);
      return await waiter.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () => null,
      );
    } catch (e) {
      _logger.e('Error publicando posición: $e');
      return null;
    } finally {
      if (_ackWaiters[sequence] == waiter) {
        _ackWaiters.remove(sequence);
      }
    }
  }

  void disconnect() {
    _completePendingAcks(null);
    _updatesSubscription?.cancel();
    _updatesSubscription = null;
    if (_client != null) {
      try {
        _client!.disconnect();
      } catch (_) {}
      _client = null;
    }
    _connected = false;
  }

  bool get isConnected => _connected;

  void _handleUpdates(List<MqttReceivedMessage<MqttMessage>> events) {
    for (final event in events) {
      if (event.topic != _ackTopic) continue;
      final message = event.payload;
      if (message is! MqttPublishMessage) continue;

      try {
        final raw = utf8.decode(message.payload.message);
        final data = jsonDecode(raw) as Map<String, dynamic>;
        final sessionId = data['sessionId'] as String?;
        final sequence = (data['sequence'] as num?)?.toInt();
        final accepted = data['accepted'] as bool?;
        if (sessionId == null ||
            sessionId != _sessionId ||
            sequence == null ||
            accepted == null) {
          continue;
        }

        _ackWaiters.remove(sequence)?.complete(PositionAck(
              sessionId: sessionId,
              sequence: sequence,
              accepted: accepted,
              reason: data['reason'] as String?,
            ));
      } catch (error) {
        _logger.w('ACK MQTT inválido: $error');
      }
    }
  }

  void _completePendingAcks(PositionAck? ack) {
    final waiters = _ackWaiters.values.toList();
    _ackWaiters.clear();
    for (final waiter in waiters) {
      if (!waiter.isCompleted) waiter.complete(ack);
    }
  }

  String? _readSessionId(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final normalized = base64Url.normalize(parts[1]);
      final payload = jsonDecode(utf8.decode(base64Url.decode(normalized)))
          as Map<String, dynamic>;
      return payload['sessionId'] as String?;
    } catch (_) {
      return null;
    }
  }
}
