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

/// Contesta como el backend al pedir los indicadores en CSV.
class _AdapterCsv implements HttpClientAdapter {
  RequestOptions? request;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    return ResponseBody.fromString(
      'ruta,hora\r\nR / 1,6\r\n',
      200,
      headers: {
        Headers.contentTypeHeader: ['text/csv; charset=utf-8'],
        'content-disposition': [
          'attachment; filename="indicadores-R___1-2026-10-01-a-2026-10-24.csv"',
        ],
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

  test(
    'los indicadores en CSV traen el texto y el nombre del archivo',
    () async {
      final adapter = _AdapterCsv();
      final dio = Dio(BaseOptions(baseUrl: 'https://panel.test'))
        ..httpClientAdapter = adapter;
      final api = FleetApi(baseUrl: 'https://panel.test', dio: dio);

      final csv = await api.fetchIndicadoresCsv(
        'sesion',
        routeId: 'R / 1',
        desde: DateTime.utc(2026, 10, 1, 5),
        hasta: DateTime.utc(2026, 10, 25, 5),
        dias: [1, 5],
      );

      expect(adapter.request!.path, '/api/panel/indicadores/R%20%2F%201');
      expect(adapter.request!.queryParameters, {
        'desde': '2026-10-01T05:00:00.000Z',
        'hasta': '2026-10-25T05:00:00.000Z',
        'dias': '1,5',
        'formato': 'csv',
      });
      expect(adapter.request!.headers['Authorization'], 'Bearer sesion');
      expect(csv.texto, 'ruta,hora\r\nR / 1,6\r\n');
      expect(csv.nombre, 'indicadores-R___1-2026-10-01-a-2026-10-24.csv');
    },
  );

  test('sin nombre en la respuesta, el CSV se llama por la ruta', () async {
    final adapter = _Adapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://panel.test'))
      ..httpClientAdapter = adapter;
    final api = FleetApi(baseUrl: 'https://panel.test', dio: dio);

    final csv = await api.fetchIndicadoresCsv(
      null,
      routeId: 'R-101',
      desde: DateTime.utc(2026, 10, 1),
      hasta: DateTime.utc(2026, 10, 2),
    );

    expect(adapter.request!.queryParameters.containsKey('dias'), false);
    expect(adapter.request!.headers.containsKey('Authorization'), false);
    expect(csv.nombre, 'indicadores-R-101.csv');
  });
}
