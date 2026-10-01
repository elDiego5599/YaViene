import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_control/core/theme/app_theme.dart';
import 'package:ya_viene_control/features/auth/domain/auth_session.dart';
import 'package:ya_viene_control/features/auth/presentation/providers/'
    'auth_providers.dart';
import 'package:ya_viene_control/features/fleet/data/fleet_api.dart';
import 'package:ya_viene_control/features/fleet/data/fleet_socket_service.dart';
import 'package:ya_viene_control/features/fleet/domain/fleet_bus.dart';
import 'package:ya_viene_control/features/fleet/domain/fleet_route.dart';
import 'package:ya_viene_control/features/fleet/presentation/providers/'
    'fleet_providers.dart';
import 'package:ya_viene_control/features/fleet/presentation/screens/'
    'dashboard_screen.dart';
import 'package:ya_viene_core/core/providers/app_providers.dart'
    show BackendUrl, backendUrlProvider;

/// Los estados de error y vacío del panel, mirados de una vez (T6.7 ·
/// inventario de estados vacíos y de error de los 3 productos).
///
/// La cabecera dice si el backend contesta o no, la lista dice qué pasa
/// cuando un filtro no tiene buses, y una sesión revocada levanta su
/// diálogo. Todo eso existía con copy y sin prueba de widget: si mañana
/// un rename rompe «Tu sesión expiró» o los huecos de las pestañas, no
/// salía nada rojo.
///
/// El arnés del dashboard es el de `teclado_panel_test.dart` (fakes de
/// API y socket, arranque real del `FleetNotifier`). El inventario
/// completo vive en `inventario-estados.md` del workspace; sus espejos
/// están en `app_pasajero/test/estados_vacios_test.dart` y
/// `YaVieneWeb/tests/estados-vacios.test.ts`.
class _FakeFleetApi extends FleetApi {
  _FakeFleetApi({List<FleetBus>? buses, List<FleetRoute>? rutas})
    : buses = buses ?? _flota,
      rutas = rutas ?? _rutas,
      super(baseUrl: 'http://localhost:3000');

  static const _flota = <FleetBus>[
    FleetBus(
      busId: 'B-1',
      companyId: 'c-1',
      routeId: 'R-1',
      placa: 'ABC123',
      visible: true,
      online: true,
      lat: 10.98,
      lon: -74.8,
    ),
    FleetBus(
      busId: 'B-2',
      companyId: 'c-1',
      routeId: 'R-1',
      placa: 'XYZ987',
      visible: true,
      online: true,
      lat: 10.99,
      lon: -74.81,
    ),
  ];

  static const _rutas = <FleetRoute>[
    FleetRoute(routeId: 'R-1', name: 'Tcherassi', total: 2, online: 2),
  ];

  final List<FleetBus> buses;
  final List<FleetRoute> rutas;

  /// Cuando está puesto, `fetchPositions` falla como si el token hubiera
  /// caducado: el `FleetNotifier` lo detecta y levanta el diálogo.
  bool expirar = false;

  @override
  Future<List<FleetBus>> fetchPositions(String token) async {
    if (expirar) throw const SessionExpiredException();
    return [...buses];
  }

  @override
  Future<List<FleetRoute>> fetchRoutes(String token) async => [...rutas];
}

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

/// Monta el dashboard con el arnés de `teclado_panel_test.dart`.
///
/// El contenedor se guarda aparte para poder desecharlo dentro de
/// `_desmontar`: el `FleetNotifier` arranca un timer periódico de 60 s y
/// el binding del test lo reclama si sigue vivo al final del cuerpo.
ProviderContainer? _contenedor;

Future<(ProviderContainer, _FakeFleetApi)> _montar(
  WidgetTester tester, {
  _FakeFleetApi? api,
}) async {
  await tester.binding.setSurfaceSize(const Size(1600, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final fake = api ?? _FakeFleetApi();
  final container = ProviderContainer(
    overrides: [
      backendUrlProvider.overrideWith(
        () => BackendUrl.fija('http://localhost:3000'),
      ),
      fleetProvider.overrideWith((ref) => FleetNotifier(ref, api: fake)),
      fleetSocketFactoryProvider.overrideWithValue((_) => _FakeSocket()),
    ],
  );
  _contenedor = container;
  container.read(authProvider.notifier).state = const AuthState(
    status: AuthStatus.authenticated,
    session: AuthSession(
      token: 'tok',
      companyId: 'c-1',
      companyName: 'Empresa 1',
    ),
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(theme: AppTheme.light, home: const DashboardScreen()),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  return (container, fake);
}

Future<void> _desmontar(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  _contenedor?.dispose();
  _contenedor = null;
  await tester.pump(const Duration(seconds: 2));
}

void main() {
  // Con Ahem (la fuente de los tests) el dashboard desborda a 1600 y los
  // desbordes rompen los taps; con las fuentes reales, no. Mismo truco
  // que `teclado_panel_test.dart`.
  setUpAll(() async {
    final manifiesto =
        json.decode(await rootBundle.loadString('FontManifest.json'))
            as List<dynamic>;
    for (final entrada in manifiesto.cast<Map<String, dynamic>>()) {
      final cargador = FontLoader(entrada['family'] as String);
      for (final fuente
          in (entrada['fonts'] as List).cast<Map<String, dynamic>>()) {
        cargador.addFont(rootBundle.load(fuente['asset'] as String));
      }
      await cargador.load();
    }
  });

  // ── Cabecera: estado de la conexión ─────────────────────────────────
  Future<void> montarCabecera(
    WidgetTester tester,
    FleetConnection conexion,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1600, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final container = ProviderContainer(
      overrides: [
        backendUrlProvider.overrideWith(
          () => BackendUrl.fija('http://localhost:3000'),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: DashboardHeader(connection: conexion, onLogout: () {}),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('conectando: la cabecera lo dice', (tester) async {
    await montarCabecera(tester, FleetConnection.connecting);

    expect(find.text('Conectando…'), findsOneWidget);
    expect(find.text('Sin conexión'), findsNothing);
  });

  testWidgets('caído: la cabecera dice Sin conexión', (tester) async {
    await montarCabecera(tester, FleetConnection.disconnected);

    expect(find.text('Sin conexión'), findsOneWidget);
    expect(find.text('Conectando…'), findsNothing);
  });

  // ── Lista: huecos de las pestañas ───────────────────────────────────
  testWidgets('una pestaña sin buses dice que no hay buses, con su copy', (
    tester,
  ) async {
    await _montar(tester);

    // Con la flota de partida (dos buses en línea y visibles) las
    // pestañas de ocultos y sin señal quedan vacías.
    await tester.tap(find.text('Ocultos'));
    await tester.pump();
    expect(find.text('Ningún bus oculto en esta ruta'), findsOneWidget);

    await tester.tap(find.text('Sin Señal'));
    await tester.pump();
    expect(find.text('Ningún bus sin señal en esta ruta'), findsOneWidget);

    await _desmontar(tester);
  });

  testWidgets('flota vacía: dice Sin buses registrados y no «selecciona '
      'una ruta»', (tester) async {
    // El catálogo sí tiene rutas, así que el panel arranca filtrado en la
    // primera (`_rutaDeArranque`) y el hueco es el de flota, no el de
    // «Selecciona una ruta».
    await _montar(tester, api: _FakeFleetApi(buses: const []));

    expect(find.text('Sin buses registrados'), findsOneWidget);
    expect(find.text('Selecciona una ruta'), findsNothing);

    await _desmontar(tester);
  });

  // ── Sesión expirada ─────────────────────────────────────────────────
  testWidgets('una sesión revocada levanta su diálogo, con su botón', (
    tester,
  ) async {
    final (container, api) = await _montar(tester);

    api.expirar = true;
    await container.read(fleetProvider.notifier).refresh();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Tu sesión expiró'), findsOneWidget);
    expect(
      find.text(
        'La sesión del administrador venció o fue revocada. '
        'Vuelve a iniciar sesión para continuar.',
      ),
      findsOneWidget,
    );
    expect(find.text('INICIAR SESIÓN'), findsOneWidget);

    await _desmontar(tester);
  });

  testWidgets('varias respuestas de sesión muerta levantan un solo aviso', (
    tester,
  ) async {
    // El dueño lo encontró así (2026-09-30): el panel abierto mucho rato
    // apiló cinco «Tu sesión expiró» y hubo que cerrarlos uno a uno. Cada
    // pedido que volvía con 401 —flota, rutas, la resincronización, una
    // acción— levantaba otro encima del anterior.
    final (container, api) = await _montar(tester);

    api.expirar = true;
    final notifier = container.read(fleetProvider.notifier);
    await Future.wait([notifier.refresh(), notifier.refreshRoutes()]);
    await tester.pump();
    await notifier.refresh();
    await tester.pump();
    await notifier.refreshRoutes();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Tu sesión expiró'), findsOneWidget);

    await _desmontar(tester);
  });
}
