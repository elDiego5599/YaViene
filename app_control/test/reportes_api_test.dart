import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_control/features/fleet/data/fleet_api.dart';

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
      jsonEncode({'rutas': [], 'celdas': []}),
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
}
