import 'dart:convert';
import 'dart:math';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:logger/logger.dart';
import '../../config.dart';

class MqttService {
  final Logger _logger = Logger();
  MqttServerClient? _client;
  bool _connected = false;

  String? _empresaId;
  String? _busId;
  String? _phoneNumber;

  Future<bool> connect({
    required String empresaId,
    required String busId,
    required String phoneNumber,
    required String jwtToken,
  }) async {
    _empresaId = empresaId;
    _busId = busId;
    _phoneNumber = phoneNumber;

    final uri = Uri.parse(AppConfig.backendUrl);
    final host = uri.host;

    _client = MqttServerClient(host, 'conductor_${busId}_${Random().nextInt(9999)}');
    _client!.port = AppConfig.mqttPort;
    _client!.keepAlivePeriod = 10;
    _client!.connectTimeoutPeriod = 5000;
    _client!.logging(on: false);
    _client!.autoReconnect = true;

    final connMsg = MqttConnectMessage()
        .withClientIdentifier('conductor_${busId}_${Random().nextInt(9999)}')
        .authenticateAs(phoneNumber, jwtToken)
        .startClean();
    _client!.connectionMessage = connMsg;

    _client!.onConnected = () {
      _connected = true;
      _logger.i('MQTT conectado a $host:${AppConfig.mqttPort}');
    };
    _client!.onDisconnected = () {
      _connected = false;
      _logger.w('MQTT desconectado');
    };

    try {
      await _client!.connect();
      return _connected;
    } catch (e) {
      _logger.e('Error conectando MQTT: $e');
      _connected = false;
      return false;
    }
  }

  bool publishPosition({
    required double lat,
    required double lon,
    double? heading,
    double? speedKmh,
  }) {
    if (!_connected || _client == null || _empresaId == null || _busId == null) return false;

    final topic = 'empresa/$_empresaId/bus/$_busId/posicion';
    final payload = jsonEncode({
      'phoneNumber': _phoneNumber,
      'lat': lat,
      'lon': lon,
      'heading': heading ?? 0.0,
      'speedKmh': speedKmh ?? 0.0,
      'timestamp': DateTime.now().toIso8601String(),
    });

    final builder = MqttClientPayloadBuilder()..addString(payload);
    _client!.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
    return true;
  }

  void disconnect() {
    _client?.disconnect();
    _client = null;
    _connected = false;
  }

  bool get isConnected => _connected;
}
