import 'package:dio/dio.dart';

import '../../../../config.dart';
import '../domain/fleet_bus.dart';

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

  Future<FleetBus> setVisibility(String token, String busId, bool visible) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/fleet/buses/$busId/visibility',
      data: {'visible': visible},
      options: _auth(token),
    );
    return FleetBus.fromJson(response.data!);
  }
}
