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
    show BackendUrl, backendUrlProvider;

class _FakeFleetApi extends FleetApi {
  _FakeFleetApi({
    this.positions,
    this.routes,
    this.throwsSessionExpired = false,
  }) : super(baseUrl: 'http://localhost:3000');

  List<FleetBus>? positions;
  final List<FleetRoute>? routes;
  final bool throwsSessionExpired;

  /// Cuántas veces se pidió la flota por REST.
  int pedidas = 0;

  /// Con qué token se pidió cada cosa (null: la cookie del panel web).
  final tokens = <String?>[];

  Completer<void>? _aviso;
  int _meta = 0;

  /// Se completa en cuanto la flota se haya pedido [cuantas] veces en total.
  /// Esperar por reloj hacía la prueba dependiente de la máquina: con la
  /// suite entera corriendo, el temporizador de 20 ms no cabía en 70 ms.
  Future<void> alLlegarA(int cuantas) {
    if (pedidas >= cuantas) return Future<void>.value();
    _meta = cuantas;
    return (_aviso = Completer<void>()).future;
  }

  @override
  Future<List<FleetBus>> fetchPositions(String? token) async {
    pedidas++;
    tokens.add(token);
    if (pedidas >= _meta && !(_aviso?.isCompleted ?? true)) _aviso!.complete();
    if (throwsSessionExpired) throw const SessionExpiredException();
    return positions ?? const [];
  }

  @override
  Future<List<FleetRoute>> fetchRoutes(String? token) async {
    if (throwsSessionExpired) throw const SessionExpiredException();
    return routes ?? const [];
  }

  @override
  Future<void> deleteRoute(String? token, String routeId) async {
    tokens.add(token);
    routes?.removeWhere((r) => r.routeId == routeId);
  }
}

/// El catálogo de rutas falla la primera vez (red caída al arrancar).
class _RutasQueFallanUnaVez extends _FakeFleetApi {
  _RutasQueFallanUnaVez({super.routes});

  var _fallo = false;

  @override
  Future<List<FleetRoute>> fetchRoutes(String? token) async {
    if (!_fallo) {
      _fallo = true;
      throw Exception('sin red');
    }
    return super.fetchRoutes(token);
  }
}

/// Un socket sin red: lo que se mete en [posiciones], [lotes] o [visibles] le
/// llega al notifier como si el backend hubiera emitido `bus:position`,
/// `fleet:batch` o `bus:visible`.
class _FakeSocket extends FleetSocketService {
  _FakeSocket() : super(baseUrl: 'http://localhost:3000', token: 'tok');

  final posiciones = StreamController<FleetBus>.broadcast();
  final lotes = StreamController<List<FleetBus>>.broadcast();
  final visibles = StreamController<FleetBus>.broadcast();

  @override
  Stream<FleetBus> get busPositionStream => posiciones.stream;

  @override
  Stream<List<FleetBus>> get busBatchStream => lotes.stream;

  @override
  Stream<FleetBus> get busVisibleStream => visibles.stream;

  @override
  void connect() {}

  @override
  void dispose() {
    posiciones.close();
    lotes.close();
    visibles.close();
    super.dispose();
  }
}

/// Lo que manda el backend en `bus:position` al panel: la posición, sin
/// placa, interno ni conductor.
FleetBus _posicion(
  String busId, {
  int sequence = 1,
  bool isGhost = false,
  bool conRumbo = true,
}) => FleetBus.fromJson({
  'busId': busId,
  'companyId': 'c-1',
  'routeId': 'R-1',
  'lat': 10.98 + sequence / 10000,
  'lon': -74.8,
  if (conRumbo) 'heading': 90,
  'speedKmh': 20,
  'capturedAt': 1000 + sequence,
  'receivedAt': 1000 + sequence,
  'sequence': sequence,
  'isGhost': isGhost,
});

/// Deja correr los eventos del stream y los futures pendientes.
Future<void> _vaciar() => Future<void>.delayed(Duration.zero);

const _session = AuthSession(
  token: 'tok',
  companyId: 'c-1',
  companyName: 'Empresa 1',
);

ProviderContainer _containerWith(
  FleetApi api, {
  FleetSocketService? socket,
  Duration? resincronizarCada,
  AuthSession session = _session,
}) {
  final container = ProviderContainer(
    overrides: [
      backendUrlProvider.overrideWith(
        () => BackendUrl.fija('http://localhost:3000'),
      ),
      fleetProvider.overrideWith(
        (ref) => FleetNotifier(
          ref,
          api: api,
          resincronizarCada: resincronizarCada ?? const Duration(seconds: 60),
        ),
      ),
      if (socket != null)
        fleetSocketFactoryProvider.overrideWithValue((_) => socket),
    ],
  );
  container.read(authProvider.notifier).state = AuthState(
    status: AuthStatus.authenticated,
    session: session,
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test(
    'refresh() ante sesión expirada marca sessionExpired y desconecta',
    () async {
      final container = _containerWith(
        _FakeFleetApi(throwsSessionExpired: true),
      );
      final notifier = container.read(fleetProvider.notifier);

      await notifier.refresh();

      expect(notifier.state.sessionExpired, true);
      expect(notifier.state.connection, FleetConnection.disconnected);
      expect(notifier.state.error, null);
    },
  );

  test('refreshRoutes() ante sesión expirada marca sessionExpired', () async {
    final container = _containerWith(_FakeFleetApi(throwsSessionExpired: true));
    final notifier = container.read(fleetProvider.notifier);

    await notifier.refreshRoutes();

    expect(notifier.state.sessionExpired, true);
  });

  // El dashboard para la flota y luego cierra la sesión: ese cierre llegaba
  // al notifier como una sesión revocada y la marca se quedaba puesta. Al
  // volver a entrar, ni las rutas ni la flota se pedían y el panel quedaba
  // sin filtros de ruta (dueño, 2026-10-27).
  test('cerrar sesión y volver a entrar pide otra vez las rutas', () async {
    final container = _containerWith(
      _FakeFleetApi(
        routes: [
          const FleetRoute(routeId: 'R-1', name: 'Ruta 1', total: 1, online: 1),
        ],
      ),
      socket: _FakeSocket(),
    );
    final notifier = container.read(fleetProvider.notifier);

    notifier.start();
    await _vaciar();
    notifier.stop();
    // Lo que hace el listener de fleetProvider al quedar sin sesión; aquí el
    // notifier va sin él (override), así que se llama a mano.
    notifier.sesionRevocada();
    notifier.start();
    await _vaciar();

    expect(notifier.state.sessionExpired, false);
    expect(notifier.state.routes.map((r) => r.routeId), ['R-1']);
    expect(notifier.state.routeFilter, 'R-1');
  });

  // En el navegador la sesión no tiene token: la lleva la cookie. Que el
  // token falte no es «sin sesión»; sin sesión es no tener AuthSession.
  test(
    'en el navegador, sin token, la flota se pide y se edita igual',
    () async {
      final api = _FakeFleetApi(
        routes: [
          const FleetRoute(routeId: 'R-1', name: 'Ruta 1', total: 0, online: 0),
        ],
      );
      final container = _containerWith(
        api,
        session: const AuthSession(
          token: null,
          companyId: 'c-1',
          companyName: 'Empresa 1',
        ),
      );
      final notifier = container.read(fleetProvider.notifier);

      await notifier.refresh();
      await notifier.removeRoute('R-1');

      // Posiciones y rutas al refrescar, y el borrado: los tres salieron.
      expect(api.tokens, [null, null, null]);
    },
  );

  test('refresh() exitoso puebla el mapa de buses por id', () async {
    const bus = FleetBus(
      busId: 'B-1',
      companyId: 'c-1',
      visible: true,
      online: true,
    );
    final container = _containerWith(_FakeFleetApi(positions: [bus]));
    final notifier = container.read(fleetProvider.notifier);

    await notifier.refresh();

    expect(notifier.state.buses['B-1'], bus);
  });

  test(
    'refreshRoutes() exitoso puebla el catálogo y fija el filtro por defecto',
    () async {
      const route = FleetRoute(
        routeId: 'R-1',
        name: 'Ruta 1',
        total: 2,
        online: 1,
      );
      final container = _containerWith(_FakeFleetApi(routes: [route]));
      final notifier = container.read(fleetProvider.notifier);

      await notifier.refreshRoutes();

      expect(notifier.state.routes, [route]);
      expect(notifier.state.routeFilter, 'R-1');
    },
  );

  // El panel abría siempre en la primera ruta del catálogo, que es la del
  // número más bajo y casi nunca la que tiene buses andando: se veía una
  // ruta vacía y parecía que la empresa no tuviera flota.
  test(
    'refreshRoutes() abre en la ruta con buses reportando, no en la primera',
    () async {
      const vacia = FleetRoute(
        routeId: 'R-101',
        name: 'B18 Tcherassi',
        total: 1,
        online: 0,
      );
      const conBuses = FleetRoute(
        routeId: 'R-106',
        name: 'C16 Calle 72',
        total: 2,
        online: 2,
      );
      final container = _containerWith(
        _FakeFleetApi(routes: [vacia, conBuses]),
      );
      final notifier = container.read(fleetProvider.notifier);

      await notifier.refreshRoutes();

      expect(notifier.state.routeFilter, 'R-106');
    },
  );

  test(
    'refreshRoutes() sin ninguna ruta reportando abre en la primera',
    () async {
      const primera = FleetRoute(
        routeId: 'R-101',
        name: 'B18 Tcherassi',
        total: 1,
        online: 0,
      );
      const segunda = FleetRoute(
        routeId: 'R-106',
        name: 'C16 Calle 72',
        total: 2,
        online: 0,
      );
      final container = _containerWith(
        _FakeFleetApi(routes: [primera, segunda]),
      );
      final notifier = container.read(fleetProvider.notifier);

      await notifier.refreshRoutes();

      expect(notifier.state.routeFilter, 'R-101');
    },
  );

  test(
    'refreshRoutes() abre en la que más buses reporta; si empatan, la primera',
    () async {
      FleetRoute ruta(String id, int online) =>
          FleetRoute(routeId: id, name: id, total: 5, online: online);
      for (final (rutas, esperada) in [
        ([ruta('R-1', 0), ruta('R-2', 1), ruta('R-3', 3)], 'R-3'),
        ([ruta('R-1', 3), ruta('R-2', 1), ruta('R-3', 0)], 'R-1'),
        ([ruta('R-1', 0), ruta('R-2', 2), ruta('R-3', 2)], 'R-2'),
      ]) {
        final container = _containerWith(_FakeFleetApi(routes: rutas));
        final notifier = container.read(fleetProvider.notifier);

        await notifier.refreshRoutes();

        expect(notifier.state.routeFilter, esperada);
      }
    },
  );

  // Riesgo: borrar una ruta cualquiera soltaba el filtro, y la recarga del
  // catálogo llevaba al operador a la ruta con más buses, no a la suya.
  test('borrar otra ruta deja al operador en la que eligió', () async {
    FleetRoute ruta(String id, int online) =>
        FleetRoute(routeId: id, name: id, total: 5, online: online);
    final container = _containerWith(
      _FakeFleetApi(routes: [ruta('R-1', 3), ruta('R-2', 0), ruta('R-3', 0)]),
    );
    final notifier = container.read(fleetProvider.notifier)
      ..setRouteFilter('R-2');

    await notifier.removeRoute('R-3');
    await _vaciar();

    expect(notifier.state.routeFilter, 'R-2');
    expect(notifier.state.routes.map((r) => r.routeId), ['R-1', 'R-2']);
  });

  test('borrar la ruta elegida suelta el filtro', () async {
    FleetRoute ruta(String id, int online) =>
        FleetRoute(routeId: id, name: id, total: 5, online: online);
    final container = _containerWith(
      _FakeFleetApi(routes: [ruta('R-1', 3), ruta('R-2', 0)]),
    );
    final notifier = container.read(fleetProvider.notifier)
      ..setRouteFilter('R-2');

    await notifier.removeRoute('R-2');
    await _vaciar();

    expect(notifier.state.routeFilter, 'R-1');
  });

  test('refreshRoutes() no pisa la ruta que el operador ya eligió', () async {
    const vacia = FleetRoute(
      routeId: 'R-101',
      name: 'B18 Tcherassi',
      total: 1,
      online: 0,
    );
    const conBuses = FleetRoute(
      routeId: 'R-106',
      name: 'C16 Calle 72',
      total: 2,
      online: 2,
    );
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
      buses: {
        'B-1': FleetBus(
          busId: 'B-1',
          companyId: 'c-1',
          visible: true,
          online: true,
        ),
      },
      routes: [FleetRoute(routeId: 'R-1', name: 'Ruta 1', total: 1, online: 1)],
      selectedBusId: 'B-1',
    );

    notifier.stop();

    expect(notifier.state.connection, FleetConnection.disconnected);
    expect(notifier.state.buses, isEmpty);
    expect(notifier.state.routes, isEmpty);
    expect(notifier.state.selectedBusId, null);
  });

  test(
    'stop() sin haber llamado start() no revienta (sin subs que cancelar)',
    () async {
      final container = _containerWith(_FakeFleetApi());
      final notifier = container.read(fleetProvider.notifier);

      expect(() => notifier.stop(), returnsNormally);
    },
  );

  // El panel se enteraba de los cambios solo por el socket: un evento que se
  // perdiera —el socket cayó un segundo, el backend se reinició— dejaba la
  // lista mintiendo hasta que el operador pulsaba «Recargar». Cada minuto
  // vuelve a pedir la flota por REST y la funde con lo que ya tiene (T2.5),
  // así que la posición en vivo no retrocede por culpa de la foto.
  group('resincronización del panel', () {
    test(
      'mientras el panel está abierto la flota se vuelve a pedir sola',
      () async {
        final api = _FakeFleetApi();
        final socket = _FakeSocket();
        final container = _containerWith(
          api,
          socket: socket,
          resincronizarCada: const Duration(milliseconds: 20),
        );
        container.read(fleetProvider.notifier).start();
        await _vaciar();
        final alArrancar = api.pedidas;

        await api.alLlegarA(alArrancar + 3).timeout(const Duration(seconds: 5));

        expect(
          api.pedidas,
          greaterThan(alArrancar + 1),
          reason:
              'el panel tiene que resincronizarse solo, sin tocar «Recargar»',
        );
      },
    );

    test(
      'un evento perdido se corrige en la siguiente resincronización',
      () async {
        // El panel cree que el bus sigue a la vista porque el `bus:hidden` no
        // le llegó; el backend ya lo tiene oculto.
        const oculto = FleetBus(
          busId: 'B-1',
          companyId: 'c-1',
          visible: false,
          online: true,
        );
        final api = _FakeFleetApi(positions: [oculto]);
        final socket = _FakeSocket();
        final container = _containerWith(
          api,
          socket: socket,
          resincronizarCada: const Duration(milliseconds: 20),
        );
        final notifier = container.read(fleetProvider.notifier)..start();
        await _vaciar();
        final alArrancar = api.pedidas;
        notifier.state = notifier.state.copyWith(
          buses: {
            'B-1': const FleetBus(
              busId: 'B-1',
              companyId: 'c-1',
              visible: true,
              online: true,
            ),
          },
        );

        await api.alLlegarA(alArrancar + 1).timeout(const Duration(seconds: 5));
        await _vaciar();

        expect(notifier.state.buses['B-1']!.visible, false);
      },
    );

    test('al volver del segundo plano la flota se pide de inmediato', () async {
      final api = _FakeFleetApi();
      final socket = _FakeSocket();
      final container = _containerWith(api, socket: socket);
      final notifier = container.read(fleetProvider.notifier)..start();
      await _vaciar();
      final alArrancar = api.pedidas;

      notifier.alVolverAlFrente();
      await _vaciar();

      expect(
        api.pedidas,
        alArrancar + 1,
        reason: 'volver a la ventana no debería esperar al siguiente minuto',
      );
    });

    // «En un momento se quitan los filtros de ruta y se muestran todos los
    // buses en el mismo mapa» (dueño, 2026-10-27): si el catálogo falla al
    // arrancar, sin rutas no hay filtro, y la resincronización no lo volvía
    // a pedir.
    test(
      'si el catálogo falla al arrancar, la resincronización lo trae',
      () async {
        final api = _RutasQueFallanUnaVez(
          routes: [
            const FleetRoute(
              routeId: 'R-1',
              name: 'Ruta 1',
              total: 0,
              online: 0,
            ),
          ],
        );
        final container = _containerWith(
          api,
          socket: _FakeSocket(),
          resincronizarCada: const Duration(milliseconds: 20),
        );
        final notifier = container.read(fleetProvider.notifier)..start();
        await _vaciar();
        expect(notifier.state.routes, isEmpty);

        await api.alLlegarA(api.pedidas + 2);
        await _vaciar();

        expect(notifier.state.routes.map((r) => r.routeId), ['R-1']);
        expect(notifier.state.routeFilter, 'R-1');
        notifier.stop();
      },
    );

    test('stop() apaga la resincronización', () async {
      final api = _FakeFleetApi();
      final socket = _FakeSocket();
      final container = _containerWith(
        api,
        socket: socket,
        resincronizarCada: const Duration(milliseconds: 20),
      );
      final notifier = container.read(fleetProvider.notifier)..start();
      await _vaciar();
      notifier.stop();
      final alParar = api.pedidas;

      // Aquí sí se espera por reloj: lo que se afirma es que no pasa nada, y
      // son diez vueltas del temporizador de resincronización.
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(
        api.pedidas,
        alParar,
        reason: 'con la sesión cerrada no se piden datos con un token muerto',
      );
    });

    test('con la sesión expirada la resincronización no insiste', () async {
      final api = _FakeFleetApi(throwsSessionExpired: true);
      final socket = _FakeSocket();
      final container = _containerWith(
        api,
        socket: socket,
        resincronizarCada: const Duration(milliseconds: 20),
      );
      final notifier = container.read(fleetProvider.notifier)..start();
      await _vaciar();
      expect(notifier.state.sessionExpired, true);
      final alExpirar = api.pedidas;

      // Diez vueltas del temporizador: si alguna insistiera, se vería.
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(api.pedidas, alExpirar);
    });
  });

  test(
    'la sesión vencida se queda vencida: otro 401 no la vuelve a anunciar',
    () async {
      final api = _FakeFleetApi(throwsSessionExpired: true);
      final container = _containerWith(api);
      final notifier = container.read(fleetProvider.notifier);
      final cambios = <bool>[];
      container.listen(
        fleetProvider.select((s) => s.sessionExpired),
        (_, v) => cambios.add(v),
      );

      await Future.wait([notifier.refresh(), notifier.refreshRoutes()]);
      final alVencer = api.pedidas;
      await notifier.refresh();
      await notifier.refreshRoutes();

      expect(cambios, [true], reason: 'una sola subida, ninguna bajada');
      expect(
        api.pedidas,
        alVencer,
        reason: 'con el token muerto ya no se pide nada',
      );

      notifier.stop();
      expect(
        notifier.state.sessionExpired,
        isFalse,
        reason: 'cerrar sesión sí la limpia',
      );
    },
  );

  group('bus:position conserva el catálogo del bus', () {
    const catalogado = FleetBus(
      busId: 'B-1',
      companyId: 'c-1',
      routeId: 'R-1',
      placa: 'ABC123',
      interno: '0457',
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

    // El backend guarda NULL cuando el bus no manda rumbo. Leerlo como 0
    // giraba el bus hacia el norte en cada posición.
    test(
      'una posición sin rumbo deja el bus mirando hacia donde iba',
      () async {
        final (notifier, socket, _) = await arrancar();

        socket.posiciones.add(_posicion('B-1', sequence: 1));
        await _vaciar();
        expect(notifier.state.buses['B-1']!.heading, 90);

        socket.posiciones.add(_posicion('B-1', sequence: 2, conRumbo: false));
        await _vaciar();
        expect(notifier.state.buses['B-1']!.sequence, 2);
        expect(notifier.state.buses['B-1']!.heading, 90);
      },
    );

    test('una posición en vivo no borra placa ni interno', () async {
      final (notifier, socket, _) = await arrancar();

      socket.posiciones.add(_posicion('B-1', sequence: 7));
      await _vaciar();

      final bus = notifier.state.buses['B-1']!;
      expect(bus.placa, 'ABC123');
      expect(bus.interno, '0457');
      expect(bus.sequence, 7);
      expect(bus.lat, closeTo(10.9807, 1e-9));
      expect(bus.online, true);
    });

    test(
      'un evento fantasma deja el bus Inactivo, igual que tras recargar por REST',
      () async {
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
      },
    );

    test('un bus desconocido aparece y dispara una sola recarga', () async {
      final (notifier, socket, api) = await arrancar(rest: const []);
      final antes = api.pedidas;
      api.positions = [catalogado.copyWith(placa: 'NUE001')];

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

    test(
      'la búsqueda por placa sigue encontrando el bus tras 100 posiciones',
      () async {
        final (notifier, socket, _) = await arrancar();

        for (var i = 1; i <= 100; i++) {
          socket.posiciones.add(_posicion('B-1', sequence: i));
        }
        await _vaciar();

        expect(notifier.state.buses['B-1']!.sequence, 100);
        expect(notifier.state.buscar('abc1').map((b) => b.busId), ['B-1']);
        expect(notifier.state.buscar('0457').map((b) => b.busId), ['B-1']);
        // El conductor ya no se ve en el panel, así que tampoco se busca por
        // él: un resultado que no dice por qué salió confunde.
        expect(notifier.state.buscar('carlos'), isEmpty);
      },
    );

    // Los mensajes no llegan en orden: el socket reconecta, el REST vuelve
    // tarde, el lote de la suscripción sale de la base. La captura del equipo
    // es lo que decide cuál es la posición del bus (T2.5).
    group('y ninguna posición más vieja lo retrocede', () {
      test('una posición vieja que llega tarde no pisa la nueva', () async {
        final (notifier, socket, _) = await arrancar();

        socket.posiciones
          ..add(_posicion('B-1', sequence: 5))
          ..add(_posicion('B-1', sequence: 3));
        await _vaciar();

        final bus = notifier.state.buses['B-1']!;
        expect(bus.sequence, 5);
        expect(bus.capturedAt, 1005);
        expect(bus.lat, closeTo(10.9805, 1e-9));
      });

      test('el fantasma con la misma captura sí cambia el estado', () async {
        final (notifier, socket, _) = await arrancar();

        socket.posiciones
          ..add(_posicion('B-1', sequence: 5))
          ..add(_posicion('B-1', sequence: 5, isGhost: true));
        await _vaciar();

        final bus = notifier.state.buses['B-1']!;
        expect(bus.isGhost, isTrue);
        expect(bus.online, isFalse);
      });

      test('un refresh REST lento no retrocede un bus', () async {
        final (notifier, socket, api) = await arrancar();
        socket.posiciones.add(_posicion('B-1', sequence: 5));
        await _vaciar();

        // El REST salió antes de esa posición y vuelve después, con la placa
        // corregida: la placa entra y la posición vieja no.
        api.positions = [
          catalogado.copyWith(
            placa: 'XYZ789',
            lat: 10.9,
            lon: -74.7,
            capturedAt: 1002,
            sequence: 2,
          ),
        ];
        await notifier.refresh();
        final bus = notifier.state.buses['B-1']!;
        expect(bus.placa, 'XYZ789');
        expect(bus.sequence, 5);
        expect(bus.lat, closeTo(10.9805, 1e-9));

        // Uno que sí es más nuevo trae su posición.
        api.positions = [
          catalogado.copyWith(
            lat: 10.9,
            lon: -74.7,
            capturedAt: 1009,
            sequence: 9,
          ),
        ];
        await notifier.refresh();
        expect(notifier.state.buses['B-1']!.sequence, 9);
        expect(notifier.state.buses['B-1']!.lat, 10.9);
      });

      test('un batch posterior a un evento vivo no lo retrocede', () async {
        final (notifier, socket, _) = await arrancar();
        socket.posiciones.add(_posicion('B-1', sequence: 5));
        await _vaciar();

        socket.lotes.add([
          catalogado.copyWith(
            lat: 10.9,
            lon: -74.7,
            capturedAt: 1002,
            sequence: 2,
          ),
        ]);
        await _vaciar();

        expect(notifier.state.buses['B-1']!.sequence, 5);
        expect(notifier.state.buses['B-1']!.placa, 'ABC123');
      });

      test(
        'bus:visible con una posición más vieja lo muestra sin retrocederlo',
        () async {
          final (notifier, socket, _) = await arrancar(
            rest: [catalogado.copyWith(visible: false)],
          );
          socket.posiciones.add(_posicion('B-1', sequence: 5));
          await _vaciar();

          socket.visibles.add(_posicion('B-1', sequence: 3));
          await _vaciar();

          final bus = notifier.state.buses['B-1']!;
          expect(bus.visible, isTrue);
          expect(bus.sequence, 5);
        },
      );
    });
  });

  test(
    'con backendUrlProvider = respaldo, el login, la flota y el socket van al respaldo',
    () {
      const respaldo = 'https://ya-viene-backend.fly.dev';
      final container = ProviderContainer(
        overrides: [
          backendUrlProvider.overrideWith(() => BackendUrl.fija(respaldo)),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(authApiProvider).baseUrl, respaldo);
      expect(container.read(fleetApiProvider).baseUrl, respaldo);
      final socket = container.read(fleetSocketFactoryProvider)('tok');
      addTearDown(socket.dispose);
      expect(socket.baseUrl, respaldo);
    },
  );

  // La URL puede cambiar con el panel abierto (al elegir antes del login).
  // Antes el cambio rehacía el notifier de la sesión, que volvía a
  // «desconocida», y el operador salía al login aunque su token siguiera
  // valiendo.
  test(
    'si la URL cambia con el panel abierto, todo pasa al respaldo sin cerrar la sesión',
    () async {
      const principal = 'https://tunel.ngrok-free.dev';
      const respaldo = 'https://ya-viene-backend.fly.dev';
      final container = ProviderContainer(
        overrides: [
          backendUrlProvider.overrideWith(
            () => BackendUrl(
              principal,
              principal: principal,
              respaldo: respaldo,
              sonda: (url, _) async => url == respaldo,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      final auth = container.read(authProvider.notifier)
        ..state = const AuthState(
          status: AuthStatus.authenticated,
          session: _session,
        );

      await container.read(backendUrlProvider.notifier).reResolver();
      await _vaciar();

      expect(container.read(backendUrlProvider), respaldo);
      expect(container.read(authApiProvider).baseUrl, respaldo);
      expect(container.read(fleetApiProvider).baseUrl, respaldo);
      final socket = container.read(fleetSocketFactoryProvider)('tok');
      addTearDown(socket.dispose);
      expect(socket.baseUrl, respaldo);
      expect(container.read(authProvider.notifier), same(auth));
      expect(container.read(authProvider).session?.token, 'tok');
    },
  );

  group(
    'FleetState — filtros y contadores (usados por el dashboard y el mapa)',
    () {
      const online = FleetBus(
        busId: 'B-1',
        companyId: 'c-1',
        routeId: 'R-1',
        visible: true,
        online: true,
      );
      const hidden = FleetBus(
        busId: 'B-2',
        companyId: 'c-1',
        routeId: 'R-1',
        visible: false,
        online: true,
      );
      const offline = FleetBus(
        busId: 'B-3',
        companyId: 'c-1',
        routeId: 'R-2',
        visible: true,
        online: false,
      );
      const ghost = FleetBus(
        busId: 'B-4',
        companyId: 'c-1',
        routeId: 'R-1',
        visible: true,
        online: true,
        isGhost: true,
      );
      final state = FleetState(
        buses: {
          for (final b in [online, hidden, offline, ghost]) b.busId: b,
        },
        routes: const [
          FleetRoute(routeId: 'R-1', name: 'Ruta uno', total: 3, online: 1),
        ],
      );

      test(
        'fleetList con statusFilter.online trae los que transmiten, ocultos o no, sin ghosts',
        () {
          final list = state
              .copyWith(statusFilter: FleetStatusFilter.online)
              .fleetList;
          expect(list.map((b) => b.busId), ['B-1', 'B-2']);
        },
      );

      test('fleetList con statusFilter.hidden solo trae los no visibles', () {
        final list = state
            .copyWith(statusFilter: FleetStatusFilter.hidden)
            .fleetList;
        expect(list.map((b) => b.busId), ['B-2']);
      });

      // Riesgo: que «Sin señal» deje fuera al bus fantasma, que transmite
      // sesión pero no posición y sí entra en el contador de sin señal.
      test(
        'fleetList con statusFilter.offline trae los desconectados y los fantasma',
        () {
          final list = state
              .copyWith(statusFilter: FleetStatusFilter.offline)
              .fleetList;
          expect(list.map((b) => b.busId), ['B-3', 'B-4']);
        },
      );

      // El número del bus se busca sin su prefijo: escribir «bus» no puede
      // traer la flota entera.
      test('buscar no cuenta el prefijo BUS- del número', () {
        final conPrefijo = FleetState(
          buses: {
            for (final id in ['BUS-101', 'BUS-202']) id: _busSinRuta(id),
          },
        );
        expect(conPrefijo.buscar('101').map((b) => b.busId), ['BUS-101']);
        expect(conPrefijo.buscar('bus'), isEmpty);
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

      test(
        'routeName usa el catálogo si existe, o "Ruta <id>" como respaldo',
        () {
          expect(state.routeName('R-1'), 'Ruta uno');
          expect(state.routeName('R-9'), 'Ruta R-9');
          expect(state.routeName(null), null);
        },
      );
    },
  );
}

FleetBus _busSinRuta(String busId) =>
    FleetBus(busId: busId, companyId: 'c-1', visible: true, online: true);
