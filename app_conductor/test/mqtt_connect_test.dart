import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:ya_viene_conductor/config.dart';
import 'package:ya_viene_conductor/features/tracking/mqtt_service.dart';

void main() {
  test('MqttService conecta con token demo', () async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
    final request = await client.postUrl(
      Uri.parse('${AppConfig.backendUrl}/api/demo/session'),
    );
    request.headers.contentType = ContentType.json;
    request.write(jsonEncode({
      'companyId': 'EMP-01',
      'busId': 'BUS-SQA101',
      'routeId': 'R-101',
    }));
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    client.close(force: true);
    expect(response.statusCode, 200, reason: 'demo session: $body');
    final token = (jsonDecode(body) as Map)['token'] as String;
    print('TOKEN: ${token.substring(0, 30)}...');

    final service = MqttService();
    final connected = await service.connect(
      empresaId: 'EMP-01',
      busId: 'BUS-SQA101',
      phoneNumber: 'demo:BUS-SQA101',
      jwtToken: token,
    );
    print('CONNECTED: $connected');
    expect(connected, true, reason: 'MQTT debe conectar con el token');

    final ack = await service.publishPosition(
      lat: 10.98095,
      lon: -74.80460,
      heading: 90,
      speedKmh: 35,
      capturedAt: DateTime.now().millisecondsSinceEpoch,
      sequence: 1,
    );
    print('ACK: ${ack?.accepted} ${ack?.reason}');
    expect(ack?.accepted, true, reason: 'La posición debe ser aceptada');
    service.disconnect();
  }, timeout: const Timeout(Duration(seconds: 30)));
}
