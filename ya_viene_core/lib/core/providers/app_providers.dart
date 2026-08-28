import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../models/company.dart';
import '../models/route_info.dart';

const String _backendUrl = String.fromEnvironment(
  'BACKEND_URL',
  defaultValue: 'http://localhost:3000',
);

Future<List<T>> _getJsonList<T>(
  String path,
  T Function(Map<String, dynamic>) fromJson,
) async {
  final response = await http
      .get(Uri.parse('$_backendUrl$path'))
      .timeout(const Duration(seconds: 8));
  if (response.statusCode != 200) {
    throw Exception('Error al cargar datos (${response.statusCode})');
  }
  final data = jsonDecode(response.body);
  if (data is! List) throw const FormatException('Respuesta inesperada');
  return data
      .map((item) => fromJson(Map<String, dynamic>.from(item as Map)))
      .toList();
}

final companiesProvider =
    FutureProvider.autoDispose<List<Company>>((ref) async {
  return _getJsonList('/api/companies', Company.fromJson);
});

// La empresa seleccionada es parte del estado persistente de la sesión (no
// es temporal de la hoja): con autoDispose, al cerrar el selector se
// desechaba y al reabrirlo decía "Primero selecciona una empresa" aunque la
// ruta siguiera activa. La limpieza explícita la hace resetAppState.
final selectedCompanyProvider =
    StateNotifierProvider<_SelectedCompanyNotifier, Company?>(
  (ref) => _SelectedCompanyNotifier(),
);

class _SelectedCompanyNotifier extends StateNotifier<Company?> {
  _SelectedCompanyNotifier() : super(null);

  void select(Company company) => state = company;
  void clear() => state = null;
}

final routesByCompanyProvider = FutureProvider.autoDispose
    .family<List<RouteInfo>, String>((ref, companyId) async {
  return _getJsonList('/api/companies/$companyId/routes', RouteInfo.fromJson);
});

// La ruta es estado de sesión igual que la empresa: no debe borrarse sola
// al cambiar de pantalla. Antes era autoDispose y se perdía si nadie la
// miraba; ahora persiste hasta que resetAppState la limpie.
final selectedRouteProvider =
    StateNotifierProvider<_SelectedRouteNotifier, RouteInfo?>(
  (ref) => _SelectedRouteNotifier(),
);

class _SelectedRouteNotifier extends StateNotifier<RouteInfo?> {
  _SelectedRouteNotifier() : super(null);

  void select(RouteInfo route) => state = route;
  void clear() => state = null;
}
