import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:ya_viene_control/features/fleet/data/fleet_socket_service.dart';

void main() {
  test('FleetSocketService conecta con token admin y recibe fleet:batch', () async {
    const backend = String.fromEnvironment('BACKEND_URL', defaultValue: 'http://localhost:3000');
    const key = String.fromEnvironment('ADMIN_API_KEY', defaultValue: '');
    final login = await http.post(
      Uri.parse('$backend/api/admin/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': 'admin', 'password': 'admin123', 'apiKey': key}),
    );
    final token = (jsonDecode(login.body) as Map)['token'] as String;
    expect(token.isNotEmpty, true, reason: 'login falló: ${login.body}');

    final service = FleetSocketService(token: token);
    final batchFuture = service.busBatchStream.first.timeout(const Duration(seconds: 10));
    final connected = <bool>[];
    service.connectionStream.listen((c) => connected.add(c));

    service.connect();
    final batch = await batchFuture;
    expect(batch.length, greaterThanOrEqualTo(1),
        reason: 'se esperaba al menos 1 bus registrado');
    expect(connected.contains(true), true, reason: 'nunca llegó connected=true');

    service.dispose();
  });
}
