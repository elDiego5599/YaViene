import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_control/features/fleet/data/fleet_api.dart';
import 'package:ya_viene_core/ya_viene_core.dart' show MotivoQueja;

class _Adapter implements HttpClientAdapter {
  RequestOptions? request;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    return ResponseBody.fromString(
      jsonEncode({'rutas': [], 'celdas': [], 'quejas': []}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test(
    'los reportes usan endpoints, hora y token del cliente del panel',
    () async {
      final adapter = _Adapter();
      final dio = Dio(BaseOptions(baseUrl: 'https://panel.test'))
        ..httpClientAdapter = adapter;
      final api = FleetApi(baseUrl: 'https://panel.test', dio: dio);
      final desde = DateTime.utc(2026, 10, 1);
      final hasta = DateTime.utc(2026, 10, 25);

      await api.fetchSearchReports(
        'sesion',
        desde: desde,
        hasta: hasta,
        hora: 6,
      );
      expect(adapter.request!.path, '/api/panel/busquedas');
      expect(adapter.request!.queryParameters['hora'], 6);
      expect(adapter.request!.queryParameters.containsKey('dias'), false);
      expect(adapter.request!.headers['Authorization'], 'Bearer sesion');

      await api.fetchSearchHeatmap(
        'sesion',
        routeId: 'R / 1',
        desde: desde,
        hasta: hasta,
        hora: 23,
        dias: [1, 3],
      );
      expect(adapter.request!.path, '/api/panel/busquedas/R%20%2F%201/calor');
      expect(adapter.request!.queryParameters['hora'], 23);
      expect(adapter.request!.queryParameters['dias'], '1,3');
      expect(adapter.request!.headers['Authorization'], 'Bearer sesion');
    },
  );

  test('las quejas piden rango, ruta, motivo y días con el token', () async {
    final adapter = _Adapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://panel.test'))
      ..httpClientAdapter = adapter;
    final api = FleetApi(baseUrl: 'https://panel.test', dio: dio);

    final reporte = await api.fetchQuejas(
      'sesion',
      desde: DateTime.utc(2026, 10, 1),
      hasta: DateTime.utc(2026, 10, 25),
      routeId: 'R-101',
      motivo: MotivoQueja.ibaLleno,
      dias: [2, 5],
    );
    expect(reporte.quejas, isEmpty);
    expect(adapter.request!.path, '/api/panel/quejas');
    expect(adapter.request!.queryParameters, {
      'desde': '2026-10-01T00:00:00.000Z',
      'hasta': '2026-10-25T00:00:00.000Z',
      'routeId': 'R-101',
      'motivo': 'iba_lleno',
      'dias': '2,5',
    });
    expect(adapter.request!.headers['Authorization'], 'Bearer sesion');

    // Sin ruta, sin motivo y sin días: todo lo de la empresa en el rango.
    await api.fetchQuejas(
      'sesion',
      desde: DateTime.utc(2026, 10, 1),
      hasta: DateTime.utc(2026, 10, 25),
    );
    expect(adapter.request!.queryParameters.keys, ['desde', 'hasta']);
  });
}
