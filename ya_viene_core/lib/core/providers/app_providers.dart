
import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/bus_position.dart';
import '../models/route_info.dart';
import '../models/company.dart';
import 'map_providers.dart' show appLifecycleProvider;


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
      });

      ref.onDispose(() {
        timer?.cancel();
        controller.close();
      });

      timer = Timer.periodic(const Duration(seconds: 3), (_) => tickCallback());

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
  await Future.delayed(const Duration(milliseconds: 500));
  return [
    const Company(id: '1', name: 'Coolitoral S.A.'),
    const Company(id: '2', name: 'Metrocaribe Ltda.'),
    const Company(id: '3', name: 'Transcaribe S.A.S.'),
  ];
});

final selectedCompanyProvider =
    StateNotifierProvider.autoDispose<SelectedCompanyNotifier, Company?>(
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
    StateNotifierProvider.autoDispose<SelectedRouteNotifier, RouteInfo?>(
      (ref) => SelectedRouteNotifier(),
    );

class SelectedRouteNotifier extends StateNotifier<RouteInfo?> {
  SelectedRouteNotifier() : super(null);

  void select(RouteInfo route) => state = route;
  void clear() => state = null;
}


enum RouteSentido { ida, vuelta }

final selectedSentidoProvider = StateProvider.autoDispose<RouteSentido>(
  (ref) => RouteSentido.ida,
);


final proximityAlertProvider = StateProvider.autoDispose<bool>((ref) => false);
