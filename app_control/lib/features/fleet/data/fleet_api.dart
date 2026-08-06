import 'package:dio/dio.dart';

import '../../../../config.dart';
import '../domain/fleet_bus.dart';
import '../domain/fleet_route.dart';

class FleetApi {
  FleetApi({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: AppConfig.backendUrl,
              connectTimeout: const Duration(seconds: 8),
              receiveTimeout: const Duration(seconds: 8),
            ));

  final Dio _dio;

  Options _auth(String token) => Options(
        headers: {'Authorization': 'Bearer $token'},
      );

  Future<List<FleetBus>> fetchPositions(String token) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/fleet/positions',
      options: _auth(token),
    );
    final buses = response.data!['buses'] as List<dynamic>;
    return buses
        .map((b) => FleetBus.fromJson(Map<String, dynamic>.from(b as Map)))
        .toList();
  }

  Future<List<FleetRoute>> fetchRoutes(String token) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/fleet/routes',
      options: _auth(token),
    );
    final routes = response.data!['routes'] as List<dynamic>;
    return routes
        .map((r) => FleetRoute.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  Future<FleetBus> setVisibility(String token, String busId, bool visible) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/fleet/buses/$busId/visibility',
      data: {'visible': visible},
      options: _auth(token),
    );
    return FleetBus.fromJson(response.data!);
  }

  Future<FleetBus> createBus(String token, {required String placa, String? routeId}) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/fleet/buses',
      data: {'placa': placa, 'routeId': routeId ?? ''},
      options: _auth(token),
    );
    return FleetBus.fromJson(response.data!);
  }

  Future<FleetBus> updateBus(
    String token,
    String busId, {
    String? placa,
    String? routeId,
  }) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/api/fleet/buses/$busId',
      data: {
        'placa': ?placa,
        'routeId': ?routeId,
      },
      options: _auth(token),
    );
    return FleetBus.fromJson(response.data!);
  }

  Future<void> deleteBus(String token, String busId) async {
    await _dio.delete<void>(
      '/api/fleet/buses/$busId',
      options: _auth(token),
    );
  }
}
