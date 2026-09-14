import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ya_viene_control/features/auth/domain/auth_session.dart';
import 'package:ya_viene_control/features/auth/presentation/providers/auth_providers.dart';
import 'package:ya_viene_control/features/fleet/data/fleet_api.dart';
import 'package:ya_viene_control/features/fleet/data/fleet_socket_service.dart';
import 'package:ya_viene_control/features/fleet/domain/fleet_bus.dart';
import 'package:ya_viene_control/features/fleet/domain/fleet_route.dart';
import 'package:ya_viene_control/features/fleet/presentation/providers/fleet_providers.dart';
import 'package:ya_viene_core/core/providers/app_providers.dart'
    show backendUrlProvider;

class _FakeFleetApi extends FleetApi {
  _FakeFleetApi({this.positions, this.routes, this.throwsSessionExpired = false})
      : super(baseUrl: 'http://localhost:3000');

  List<FleetBus>? positions;
  final List<FleetRoute>? routes;
  final bool throwsSessionExpired;

  /// Cuántas veces se pidió la flota por REST.
  int pedidas = 0;

  @override
  Future<List<FleetBus>> fetchPositions(String token) async {
    pedidas++;
    if (throwsSessionExpired) throw const SessionExpiredException();
    return positions ?? const [];
  }

  @override
  Future<List<FleetRoute>> fetchRoutes(String token) async {
    if (throwsSessionExpired) throw const SessionExpiredException();
    return routes ?? const [];
  }
}

/// Un socket sin red: lo que se mete en [posiciones] le llega al notifier
/// como si el backend hubiera emitido `bus:position`.
class _FakeSocket extends FleetSocketService {
  _FakeSocket() : super(baseUrl: 'http://localhost:3000', token: 'tok');

  final posiciones = StreamController<FleetBus>.broadcast();

  @override
  Stream<FleetBus> get busPositionStream => posiciones.stream;

  @override
  void connect() {}

  @override
  void dispose() {
    posiciones.close();
    super.dispose();
  }
}

/// Lo que manda el backend en `bus:position` al panel: la posición, sin
/// placa, interno ni conductor.
FleetBus _posicion(String busId, {int sequence = 1, bool isGhost = false}) =>
    FleetBus.fromJson({
      'busId': busId,
      'companyId': 'c-1',
      'routeId': 'R-1',
      'lat': 10.98 + sequence / 10000,
      'lon': -74.8,
      'heading': 90,
      'speedKmh': 20,
      'capturedAt': 1000 + sequence,
      'receivedAt': 1000 + sequence,
      'sequence': sequence,
      'isGhost': isGhost,
    });

/// Deja correr los eventos del stream y los futures pendientes.
Future<void> _vaciar() => Future<void>.delayed(Duration.zero);

const _session = AuthSession(token: 'tok', companyId: 'c-1', companyName: 'Empresa 1');

ProviderContainer _containerWith(FleetApi api, {FleetSocketService? socket}) {
  final container = ProviderContainer(
    overrides: [
      backendUrlProvider.overrideWithValue('http://localhost:3000'),
      fleetProvider.overrideWith((ref) => FleetNotifier(ref, api: api)),
      if (socket != null) fleetSocketFactoryProvider.overrideWithValue((_) => socket),
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

  // El panel abría siempre en la primera ruta del catálogo, que es la del
  // número más bajo y casi nunca la que tiene buses andando: se veía una
  // ruta vacía y parecía que la empresa no tuviera flota.
  test('refreshRoutes() abre en la ruta con buses reportando, no en la primera', () async {
    const vacia = FleetRoute(routeId: 'R-101', name: 'B18 Tcherassi', total: 1, online: 0);
    const conBuses = FleetRoute(routeId: 'R-106', name: 'C16 Calle 72', total: 2, online: 2);
    final container = _containerWith(_FakeFleetApi(routes: [vacia, conBuses]));
    final notifier = container.read(fleetProvider.notifier);

    await notifier.refreshRoutes();

    expect(notifier.state.routeFilter, 'R-106');
  });

  test('refreshRoutes() sin ninguna ruta reportando abre en la primera', () async {
    const primera = FleetRoute(routeId: 'R-101', name: 'B18 Tcherassi', total: 1, online: 0);
    const segunda = FleetRoute(routeId: 'R-106', name: 'C16 Calle 72', total: 2, online: 0);
    final container = _containerWith(_FakeFleetApi(routes: [primera, segunda]));
    final notifier = container.read(fleetProvider.notifier);

    await notifier.refreshRoutes();

    expect(notifier.state.routeFilter, 'R-101');
  });

  test('refreshRoutes() no pisa la ruta que el operador ya eligió', () async {
    const vacia = FleetRoute(routeId: 'R-101', name: 'B18 Tcherassi', total: 1, online: 0);
    const conBuses = FleetRoute(routeId: 'R-106', name: 'C16 Calle 72', total: 2, online: 2);
    final container = _containerWith(_FakeFleetApi(routes: [vacia, conBuses]));
    final notifier = container.read(fleetProvider.notifier);
    notifier.state = notifier.state.copyWith(routeFilter: () => 'R-101');

    await notifier.refreshRoutes();

    expect(notifier.state.routeFilter, 'R-101');
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

  group('bus:position conserva el catálogo del bus', () {
    const catalogado = FleetBus(
      busId: 'B-1',
      companyId: 'c-1',
      routeId: 'R-1',
      placa: 'ABC123',
      interno: '0457',
      driverName: 'Carlos Pérez',
      visible: true,
      online: true,
    );

    Future<(FleetNotifier, _FakeSocket, _FakeFleetApi)> arrancar({
      List<FleetBus>? rest,
    }) async {
      final api = _FakeFleetApi(positions: rest ?? [catalogado]);
      final socket = _FakeSocket();
      final container = _containerWith(api, socket: socket);
      final notifier = container.read(fleetProvider.notifier)..start();
      await _vaciar();
      return (notifier, socket, api);
    }

    test('una posición en vivo no borra placa, interno ni conductor', () async {
      final (notifier, socket, _) = await arrancar();

      socket.posiciones.add(_posicion('B-1', sequence: 7));
      await _vaciar();

      final bus = notifier.state.buses['B-1']!;
      expect(bus.placa, 'ABC123');
      expect(bus.interno, '0457');
      expect(bus.driverName, 'Carlos Pérez');
      expect(bus.sequence, 7);
      expect(bus.lat, closeTo(10.9807, 1e-9));
      expect(bus.online, true);
    });

    test('un evento fantasma deja el bus Inactivo, igual que tras recargar por REST', () async {
      final (notifier, socket, api) = await arrancar();

      socket.posiciones.add(_posicion('B-1', sequence: 8, isGhost: true));
      await _vaciar();
      final porSocket = notifier.state.buses['B-1']!;
      expect(porSocket.online, false);
      expect(notifier.state.offlineBuses, 1);

      // Lo que devuelve getFleetPositions para ese mismo bus fantasma.
      api.positions = [catalogado.copyWith(online: false, isGhost: true)];
      await notifier.refresh();
      final porRest = notifier.state.buses['B-1']!;
      expect(porSocket.online, porRest.online);
      expect(porSocket.isGhost, porRest.isGhost);
    });

    test('un bus desconocido aparece y dispara una sola recarga', () async {
      final (notifier, socket, api) = await arrancar(rest: const []);
      final antes = api.pedidas;
      api.positions = [
        catalogado.copyWith(placa: 'NUE001'),
      ];

      socket.posiciones
        ..add(_posicion('B-1'))
        ..add(_posicion('B-1', sequence: 2))
        ..add(_posicion('B-9'));
      await _vaciar();
      expect(notifier.state.buses.keys, containsAll(['B-1', 'B-9']));
      expect(api.pedidas, antes, reason: 'la recarga espera un segundo');

      await Future<void>.delayed(const Duration(milliseconds: 1200));
      expect(api.pedidas, antes + 1);
      expect(notifier.state.buses['B-1']!.placa, 'NUE001');
    });

    test('la búsqueda por placa sigue encontrando el bus tras 100 posiciones', () async {
      final (notifier, socket, _) = await arrancar();

      for (var i = 1; i <= 100; i++) {
        socket.posiciones.add(_posicion('B-1', sequence: i));
      }
      await _vaciar();

      expect(notifier.state.buses['B-1']!.sequence, 100);
      expect(notifier.state.buscar('abc1').map((b) => b.busId), ['B-1']);
      expect(notifier.state.buscar('0457').map((b) => b.busId), ['B-1']);
      expect(notifier.state.buscar('carlos').map((b) => b.busId), ['B-1']);
    });
  });

  test('con backendUrlProvider = respaldo, el login, la flota y el socket van al respaldo', () {
    const respaldo = 'https://ya-viene-backend.fly.dev';
    final container = ProviderContainer(
      overrides: [backendUrlProvider.overrideWithValue(respaldo)],
    );
    addTearDown(container.dispose);

    expect(container.read(authApiProvider).baseUrl, respaldo);
    expect(container.read(fleetApiProvider).baseUrl, respaldo);
    final socket = container.read(fleetSocketFactoryProvider)('tok');
    addTearDown(socket.dispose);
    expect(socket.baseUrl, respaldo);
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
