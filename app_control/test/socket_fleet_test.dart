import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:ya_viene_control/features/fleet/data/fleet_socket_service.dart';

void main() {
  test('FleetSocketService conecta con token admin y recibe fleet:batch', () async {
    const backend = String.fromEnvironment('BACKEND_URL', defaultValue: 'http://localhost:3000');
    const key = String.fromEnvironment('ADMIN_API_KEY', defaultValue: '');
    const username = String.fromEnvironment('ADMIN_USERNAME');
    const password = String.fromEnvironment('ADMIN_PASSWORD');
    if (username.isEmpty || password.isEmpty) {
      markTestSkipped(
        'Requiere --dart-define=ADMIN_USERNAME=... --dart-define=ADMIN_PASSWORD=... '
        'de una cuenta creada con scripts/crear-admin-empresa.mjs',
      );
      return;
    }
    final login = await http.post(
      Uri.parse('$backend/api/admin/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password, 'apiKey': key}),
    );
    final token = (jsonDecode(login.body) as Map)['token'] as String;
    expect(token.isNotEmpty, true, reason: 'login falló: ${login.body}');

    final service = FleetSocketService(baseUrl: backend, token: token);
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
