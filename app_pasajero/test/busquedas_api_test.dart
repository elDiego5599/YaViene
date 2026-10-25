import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ya_viene_pasajero/features/map/data/busquedas_api.dart';

void main() {
  test('envía una búsqueda con la celda centralizada y redondeada', () async {
    final requests = <http.Request>[];
    final contrato = jsonDecode(
      File(
        '../ya_viene_core/test/fixtures/contrato/rest-busqueda-registrada.json',
      ).readAsStringSync(),
    ) as Map<String, dynamic>;
    final client = MockClient((request) async {
      requests.add(request);
      return http.Response('', contrato['status'] as int);
    });

    await registrarBusqueda(
      backendUrl: 'https://api.test',
      routeId: 'R1',
      lat: 11.0048,
      lng: -74.8078,
      client: client,
    );

    expect(requests, hasLength(1));
    expect(requests.single.method, 'POST');
    expect(contrato['status'], 204);
    expect(requests.single.url.path, '/api/busquedas');
    expect(jsonDecode(requests.single.body), {
      'routeId': 'R1',
      'celda': {'lat': 11.0052, 'lng': -74.80748},
    });
  });

  test('no incluye celda cuando no hay pin', () async {
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      return http.Response('', 204);
    });

    await registrarBusqueda(
      backendUrl: 'https://api.test',
      routeId: 'R1',
      lat: null,
      lng: null,
      client: client,
    );

    expect(requests, hasLength(1));
    expect(jsonDecode(requests.single.body), {'routeId': 'R1'});
  });

  test('un error de red no se propaga ni repite el envío', () async {
    var sends = 0;
    final client = MockClient((request) async {
      sends++;
      throw http.ClientException('sin conexión');
    });

    await registrarBusqueda(
      backendUrl: 'https://api.test',
      routeId: 'R1',
      lat: null,
      lng: null,
      client: client,
    );
    expect(sends, 1);
  });
}
