
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/bus_position.dart';
import '../models/route_info.dart';
import '../models/company.dart';


final realtimeTickProvider = StreamProvider.autoDispose<int>((ref) async* {
  int tick = 0;
  while (true) {
    await Future.delayed(const Duration(seconds: 3));
    yield tick++;
  }
});


final busPositionsProvider = StreamProvider.autoDispose
    .family<List<BusPosition>, String>((ref, routeId) async* {
      double baseLat = 11.0041;
      double baseLon = -74.8070;

      yield _generateDummyPositions(routeId, baseLat, baseLon, tick: 0);

      int tick = 0;
      await for (final _ in Stream.periodic(const Duration(seconds: 3))) {
        tick++;
        baseLat += 0.0001 * tick;
        yield _generateDummyPositions(routeId, baseLat, baseLon, tick: tick);
      }
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


final companiesProvider = FutureProvider<List<Company>>((ref) async {
  await Future.delayed(const Duration(milliseconds: 500));
  return [
    const Company(id: '1', name: 'Coolitoral S.A.'),
    const Company(id: '2', name: 'Metrocaribe Ltda.'),
    const Company(id: '3', name: 'Transcaribe S.A.S.'),
  ];
});

final selectedCompanyProvider =
    StateNotifierProvider<SelectedCompanyNotifier, Company?>(
      (ref) => SelectedCompanyNotifier(),
    );

class SelectedCompanyNotifier extends StateNotifier<Company?> {
  SelectedCompanyNotifier() : super(null);

  void select(Company company) => state = company;
  void clear() => state = null;
}


final routesByCompanyProvider = FutureProvider.autoDispose
    .family<List<RouteInfo>, String>((ref, companyId) async {
      await Future.delayed(const Duration(milliseconds: 300));
      final allRoutes = {
        '1': [
          const RouteInfo(
            id: '101',
            name: 'Ruta 1 - Centro/Soledad',
            companyId: '1',
          ),
          const RouteInfo(
            id: '102',
            name: 'Ruta 2 - Murillo/Terminal',
            companyId: '1',
          ),
        ],
        '2': [
          const RouteInfo(
            id: '201',
            name: 'Ruta 5 - Riomar/Abello',
            companyId: '2',
          ),
        ],
        '3': [
          const RouteInfo(
            id: '301',
            name: 'Troncal - Portal/Caribe',
            companyId: '3',
          ),
        ],
      };
      return allRoutes[companyId] ?? [];
    });

final selectedRouteProvider =
    StateNotifierProvider<SelectedRouteNotifier, RouteInfo?>(
      (ref) => SelectedRouteNotifier(),
    );

class SelectedRouteNotifier extends StateNotifier<RouteInfo?> {
  SelectedRouteNotifier() : super(null);

  void select(RouteInfo route) => state = route;
  void clear() => state = null;
}


enum RouteSentido { ida, vuelta }

final selectedSentidoProvider = StateProvider<RouteSentido>(
  (ref) => RouteSentido.ida,
);


final proximityAlertProvider = StateProvider<bool>((ref) => false);
