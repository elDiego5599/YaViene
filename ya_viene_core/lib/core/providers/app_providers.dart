
import 'dart:async';
import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../models/bus_position.dart';
import '../models/route_info.dart';
import '../models/company.dart';
import 'map_providers.dart' show appLifecycleProvider;

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

/// Lanza los buses simulados de la demo para una ruta. Devuelve `true` si el
/// backend confirmó el arranque (HTTP 200); `false` ante error de red, timeout
/// o respuesta no exitosa, para que la UI no aparente éxito en falso.
/// [client] se inyecta en tests; por defecto usa el cliente global.
Future<bool> triggerDemoBuses(
  String companyId,
  String routeId, {
  http.Client? client,
}) async {
  final httpClient = client ?? http.Client();
  try {
    final response = await httpClient
        .post(
          Uri.parse('$_backendUrl/api/demo/buses'),
          headers: {'content-type': 'application/json'},
          body: jsonEncode({'companyId': companyId, 'routeId': routeId}),
        )
        .timeout(const Duration(seconds: 5));
    return response.statusCode == 200;
  } catch (_) {
    return false;
  } finally {
    if (client == null) httpClient.close();
  }
}


final busPositionsProvider = StreamProvider.autoDispose
    .family<List<BusPosition>, String>((ref, routeId) {
      final controller = StreamController<List<BusPosition>>();
      int tick = 0;
      double baseLat = 11.0041;
      double baseLon = -74.8070;
      Timer? timer;

      controller.add(_generateDummyPositions(routeId, baseLat, baseLon, tick: 0));

      void tickCallback() {
        tick++;
        baseLat += 0.0001 * tick;
        controller.add(_generateDummyPositions(routeId, baseLat, baseLon, tick: tick));
      }

      ref.listen(appLifecycleProvider, (_, state) {
        if (state == AppLifecycleState.resumed) {
          timer ??= Timer.periodic(const Duration(seconds: 3), (_) => tickCallback());
        } else {
          timer?.cancel();
          timer = null;
        }
      }, fireImmediately: true);

      ref.onDispose(() {
        timer?.cancel();
        controller.close();
      });

      return controller.stream;
    });

List<BusPosition> _generateDummyPositions(
  String routeId,
  double baseLat,
  double baseLon, {
  required int tick,
}) {
  return [
    BusPosition(
      busId: 'B-001',
      routeId: routeId,
      lat: baseLat,
      lon: baseLon,
      heading: 45,
      speedKmh: 35,
      timestamp: DateTime.now(),
      isGhostBus: false,
    ),
    BusPosition(
      busId: 'B-002',
      routeId: routeId,
      lat: baseLat + 0.005,
      lon: baseLon + 0.003,
      heading: 48,
      speedKmh: 28,
      timestamp: DateTime.now().subtract(const Duration(seconds: 95)),
      isGhostBus: true,
    ),
    BusPosition(
      busId: 'B-003',
      routeId: routeId,
      lat: baseLat + 0.012,
      lon: baseLon + 0.007,
      heading: 52,
      speedKmh: 42,
      timestamp: DateTime.now(),
      isGhostBus: false,
    ),
  ];
}


final companiesProvider = FutureProvider.autoDispose<List<Company>>((ref) async {
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

final selectedRouteProvider =
    StateNotifierProvider.autoDispose<_SelectedRouteNotifier, RouteInfo?>(
      (ref) => _SelectedRouteNotifier(),
    );

class _SelectedRouteNotifier extends StateNotifier<RouteInfo?> {
  _SelectedRouteNotifier() : super(null);

  void select(RouteInfo route) => state = route;
  void clear() => state = null;
}


enum RouteSentido { ida, vuelta }

final selectedSentidoProvider = StateProvider.autoDispose<RouteSentido>(
  (ref) => RouteSentido.ida,
);


final proximityAlertProvider = StateProvider.autoDispose<bool>((ref) => false);
