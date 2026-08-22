import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ya_viene_control/features/auth/domain/auth_session.dart';
import 'package:ya_viene_control/features/auth/presentation/providers/auth_providers.dart';
import 'package:ya_viene_control/features/fleet/data/fleet_api.dart';
import 'package:ya_viene_control/features/fleet/domain/fleet_bus.dart';
import 'package:ya_viene_control/features/fleet/domain/fleet_route.dart';
import 'package:ya_viene_control/features/fleet/presentation/providers/fleet_providers.dart';

class _FakeFleetApi extends FleetApi {
  _FakeFleetApi({this.positions, this.routes, this.throwsSessionExpired = false});

  final List<FleetBus>? positions;
  final List<FleetRoute>? routes;
  final bool throwsSessionExpired;

  @override
  Future<List<FleetBus>> fetchPositions(String token) async {
    if (throwsSessionExpired) throw const SessionExpiredException();
    return positions ?? const [];
  }

  @override
  Future<List<FleetRoute>> fetchRoutes(String token) async {
    if (throwsSessionExpired) throw const SessionExpiredException();
    return routes ?? const [];
  }
}

const _session = AuthSession(token: 'tok', companyId: 'c-1', companyName: 'Empresa 1');

ProviderContainer _containerWith(FleetApi api) {
  final container = ProviderContainer(
    overrides: [
      fleetProvider.overrideWith((ref) => FleetNotifier(ref, api: api)),
    ],
  );
  container.read(authProvider.notifier).state =
      const AuthState(status: AuthStatus.authenticated, session: _session);
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('refresh() ante sesión expirada marca sessionExpired y desconecta', () async {
    final container = _containerWith(_FakeFleetApi(throwsSessionExpired: true));
    final notifier = container.read(fleetProvider.notifier);

    await notifier.refresh();

    expect(notifier.state.sessionExpired, true);
    expect(notifier.state.connection, FleetConnection.disconnected);
    expect(notifier.state.error, null);
  });

  test('refreshRoutes() ante sesión expirada marca sessionExpired', () async {
    final container = _containerWith(_FakeFleetApi(throwsSessionExpired: true));
    final notifier = container.read(fleetProvider.notifier);

    await notifier.refreshRoutes();

    expect(notifier.state.sessionExpired, true);
  });

  test('refresh() exitoso puebla el mapa de buses por id', () async {
    const bus = FleetBus(busId: 'B-1', companyId: 'c-1', visible: true, online: true);
    final container = _containerWith(_FakeFleetApi(positions: [bus]));
    final notifier = container.read(fleetProvider.notifier);

    await notifier.refresh();

    expect(notifier.state.buses['B-1'], bus);
  });

  test('refreshRoutes() exitoso puebla el catálogo y fija el filtro por defecto', () async {
    const route = FleetRoute(routeId: 'R-1', name: 'Ruta 1', total: 2, online: 1);
    final container = _containerWith(_FakeFleetApi(routes: [route]));
    final notifier = container.read(fleetProvider.notifier);

    await notifier.refreshRoutes();

    expect(notifier.state.routes, [route]);
    expect(notifier.state.routeFilter, 'R-1');
  });

  test('stop() cierra la flota y resetea el estado a desconectado', () async {
    final container = _containerWith(_FakeFleetApi());
    final notifier = container.read(fleetProvider.notifier);
    notifier.state = const FleetState(
      connection: FleetConnection.connected,
      buses: {'B-1': FleetBus(busId: 'B-1', companyId: 'c-1', visible: true, online: true)},
      routes: [FleetRoute(routeId: 'R-1', name: 'Ruta 1', total: 1, online: 1)],
      selectedBusId: 'B-1',
    );

    notifier.stop();

    expect(notifier.state.connection, FleetConnection.disconnected);
    expect(notifier.state.buses, isEmpty);
    expect(notifier.state.routes, isEmpty);
    expect(notifier.state.selectedBusId, null);
  });

  test('stop() sin haber llamado start() no revienta (sin subs que cancelar)', () async {
    final container = _containerWith(_FakeFleetApi());
    final notifier = container.read(fleetProvider.notifier);

    expect(() => notifier.stop(), returnsNormally);
  });

  test('acknowledgeSessionExpired() solo cambia estado si estaba marcado', () async {
    final container = _containerWith(_FakeFleetApi());
    final notifier = container.read(fleetProvider.notifier);
    notifier.state = notifier.state.copyWith(sessionExpired: true);

    notifier.acknowledgeSessionExpired();

    expect(notifier.state.sessionExpired, false);
  });

  group('FleetState — filtros y contadores (usados por el dashboard y el mapa)', () {
    const online = FleetBus(busId: 'B-1', companyId: 'c-1', routeId: 'R-1', visible: true, online: true);
    const hidden = FleetBus(busId: 'B-2', companyId: 'c-1', routeId: 'R-1', visible: false, online: true);
    const offline = FleetBus(busId: 'B-3', companyId: 'c-1', routeId: 'R-2', visible: true, online: false);
    const ghost = FleetBus(
        busId: 'B-4', companyId: 'c-1', routeId: 'R-1', visible: true, online: true, isGhost: true);
    final state = FleetState(
      buses: {for (final b in [online, hidden, offline, ghost]) b.busId: b},
      routes: const [FleetRoute(routeId: 'R-1', name: 'Ruta uno', total: 3, online: 1)],
    );

    test('fleetList con statusFilter.online trae los que transmiten, ocultos o no, sin ghosts', () {
      final list = state.copyWith(statusFilter: FleetStatusFilter.online).fleetList;
      expect(list.map((b) => b.busId), ['B-1', 'B-2']);
    });

    test('fleetList con statusFilter.hidden solo trae los no visibles', () {
      final list = state.copyWith(statusFilter: FleetStatusFilter.hidden).fleetList;
      expect(list.map((b) => b.busId), ['B-2']);
    });

    test('fleetList respeta routeFilter además del statusFilter', () {
      final list = state.copyWith(routeFilter: () => 'R-2').fleetList;
      expect(list.map((b) => b.busId), ['B-3']);
    });

    test('contadores online/hidden/offline cuentan ghosts como offline', () {
      expect(state.onlineBuses, 2); // online + hidden, ambos transmiten
      expect(state.hiddenBuses, 1);
      expect(state.offlineBuses, 2); // offline + ghost
      expect(state.totalBuses, 4);
    });

    test('routeName usa el catálogo si existe, o "Ruta <id>" como respaldo', () {
      expect(state.routeName('R-1'), 'Ruta uno');
      expect(state.routeName('R-9'), 'Ruta R-9');
      expect(state.routeName(null), null);
    });
  });
}
