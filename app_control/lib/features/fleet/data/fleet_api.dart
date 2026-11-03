import 'package:dio/dio.dart';

import '../../auth/data/auth_api.dart';

import '../domain/fleet_bus.dart';
import '../domain/fleet_route.dart';

class FleetApi {
  /// [baseUrl] es el backend que resolvió el arranque (`backendUrlProvider`),
  /// no `AppConfig.backendUrl`: si el túnel no contestó y el panel entró por
  /// el respaldo, la flota tiene que pedirse al mismo sitio.
  FleetApi({required String baseUrl, Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: baseUrl,
              connectTimeout: const Duration(seconds: 8),
              receiveTimeout: const Duration(seconds: 8),
              extra: AuthApi.conCookie,
            ),
          );

  final Dio _dio;

  /// A qué backend pregunta.
  String get baseUrl => _dio.options.baseUrl;

  Options _auth(String? token) => AuthApi.cabeceras(token);

  /// Convierte un 401 en una señal clara de "tu sesión expiró" para que la
  /// app cierre sesión con un aviso en vez de quedarse con errores genéricos.
  Future<T> _guard<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw const SessionExpiredException();
      }
      rethrow;
    }
  }

  Future<List<FleetBus>> fetchPositions(String? token) async {
    final response = await _guard(
      () => _dio.get<Map<String, dynamic>>(
        '/api/fleet/positions',
        options: _auth(token),
      ),
    );
    final buses = response.data!['buses'] as List<dynamic>;
    return buses
        .map((b) => FleetBus.fromJson(Map<String, dynamic>.from(b as Map)))
        .toList();
  }

  Future<List<FleetRoute>> fetchRoutes(String? token) async {
    final response = await _guard(
      () => _dio.get<Map<String, dynamic>>(
        '/api/fleet/routes',
        options: _auth(token),
      ),
    );
    final routes = response.data!['routes'] as List<dynamic>;
    return routes
        .map((r) => FleetRoute.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  Future<Map<String, dynamic>> fetchSearchReports(
    String? token, {
    required DateTime desde,
    required DateTime hasta,
    int? hora,
    List<int> dias = const [],
  }) async {
    final response = await _guard(
      () => _dio.get<Map<String, dynamic>>(
        '/api/panel/busquedas',
        queryParameters: {
          'desde': desde.toUtc().toIso8601String(),
          'hasta': hasta.toUtc().toIso8601String(),
          'hora': ?hora,
          // Del 1 (lunes) al 7 (domingo); sin días, todos.
          if (dias.isNotEmpty) 'dias': dias.join(','),
        },
        options: _auth(token),
      ),
    );
    return response.data!;
  }

  Future<Map<String, dynamic>> fetchSearchHeatmap(
    String? token, {
    required String routeId,
    required DateTime desde,
    required DateTime hasta,
    int? hora,
    List<int> dias = const [],
  }) async {
    final response = await _guard(
      () => _dio.get<Map<String, dynamic>>(
        '/api/panel/busquedas/${Uri.encodeComponent(routeId)}/calor',
        queryParameters: {
          'desde': desde.toUtc().toIso8601String(),
          'hasta': hasta.toUtc().toIso8601String(),
          'hora': ?hora,
          // Del 1 (lunes) al 7 (domingo); sin días, todos.
          if (dias.isNotEmpty) 'dias': dias.join(','),
        },
        options: _auth(token),
      ),
    );
    return response.data!;
  }

  Future<FleetBus> setVisibility(
    String? token,
    String busId,
    bool visible,
  ) async {
    final response = await _guard(
      () => _dio.post<Map<String, dynamic>>(
        '/api/fleet/buses/$busId/visibility',
        data: {'visible': visible},
        options: _auth(token),
      ),
    );
    return FleetBus.fromJson(response.data!);
  }

  Future<int> setAllVisibility(String? token, bool visible) async {
    final response = await _guard(
      () => _dio.post<Map<String, dynamic>>(
        '/api/fleet/buses/visibility',
        data: {'visible': visible},
        options: _auth(token),
      ),
    );
    return (response.data!['count'] as num).toInt();
  }

  Future<FleetBus> createBus(
    String? token, {
    required String placa,
    String? routeId,
    String? interno,
  }) async {
    final response = await _guard(
      () => _dio.post<Map<String, dynamic>>(
        '/api/fleet/buses',
        data: {
          'placa': placa,
          'routeId': routeId ?? '',
          'interno': interno ?? '',
        },
        options: _auth(token),
      ),
    );
    return FleetBus.fromJson(response.data!);
  }

  Future<FleetBus> updateBus(
    String? token,
    String busId, {
    String? placa,
    String? routeId,
    String? interno,
  }) async {
    final response = await _guard(
      () => _dio.patch<Map<String, dynamic>>(
        '/api/fleet/buses/$busId',
        data: {'placa': ?placa, 'routeId': ?routeId, 'interno': ?interno},
        options: _auth(token),
      ),
    );
    return FleetBus.fromJson(response.data!);
  }

  Future<FleetRoute> createRoute(String? token, {required String name}) async {
    final response = await _guard(
      () => _dio.post<Map<String, dynamic>>(
        '/api/fleet/routes',
        data: {'routeId': '', 'name': name},
        options: _auth(token),
      ),
    );
    return FleetRoute.fromJson(response.data!);
  }

  Future<FleetRoute> renameRoute(
    String? token,
    String routeId, {
    required String name,
  }) async {
    final response = await _guard(
      () => _dio.patch<Map<String, dynamic>>(
        '/api/fleet/routes/$routeId',
        data: {'name': name},
        options: _auth(token),
      ),
    );
    return FleetRoute.fromJson(response.data!);
  }

  Future<void> deleteRoute(String? token, String routeId) async {
    await _guard(
      () => _dio.delete<void>(
        '/api/fleet/routes/$routeId',
        options: _auth(token),
      ),
    );
  }

  Future<void> deleteBus(String? token, String busId) async {
    await _guard(
      () => _dio.delete<void>('/api/fleet/buses/$busId', options: _auth(token)),
    );
  }
}

/// La sesión del admin expiró o fue revocada (token inválido, 401).
class SessionExpiredException implements Exception {
  const SessionExpiredException();
}
