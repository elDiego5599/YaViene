// Una posición no rehace el dashboard (R-27, N-PERF1).
//
// Con doce buses reportando cada segundo, cada `bus:position` reconstruía el
// dashboard entero —cabecera, filtros, pestañas y todas las tarjetas— aunque
// la lista no enseñe dónde está cada bus: eso solo lo pinta el mapa. Ahora
// el dashboard se suscribe con `select` a lo que sí pinta. Aquí se mira el
// widget de cada tarjeta: si el dashboard no se reconstruyó, sigue siendo
// la misma instancia. Con la tipografía de la app, como
// teclado_panel_test.dart.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_control/core/theme/app_theme.dart';
import 'package:ya_viene_control/features/auth/domain/auth_session.dart';
import 'package:ya_viene_control/features/auth/presentation/providers/auth_providers.dart';
import 'package:ya_viene_control/features/fleet/data/fleet_api.dart';
import 'package:ya_viene_control/features/fleet/data/fleet_socket_service.dart';
import 'package:ya_viene_control/features/fleet/domain/fleet_bus.dart';
import 'package:ya_viene_control/features/fleet/domain/fleet_route.dart';
import 'package:ya_viene_control/features/fleet/presentation/providers/fleet_providers.dart';
import 'package:ya_viene_control/features/fleet/presentation/screens/dashboard_screen.dart';
import 'package:ya_viene_control/features/fleet/presentation/widgets/fleet_list_tile.dart';
import 'package:ya_viene_control/features/fleet/presentation/widgets/velocidad_bus.dart';
import 'package:ya_viene_core/core/providers/app_providers.dart'
    show BackendUrl, backendUrlProvider;

class _FakeFleetApi extends FleetApi {
  _FakeFleetApi() : super(baseUrl: 'http://localhost:3000');

  @override
  Future<List<FleetBus>> fetchPositions(String token) async => const [
    FleetBus(
      busId: 'B-1',
      companyId: 'c-1',
      routeId: 'R-1',
      placa: 'ABC123',
      visible: true,
      online: true,
      lat: 10.98,
      lon: -74.8,
      capturedAt: 1000,
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
      capturedAt: 1000,
    ),
  ];

  @override
  Future<List<FleetRoute>> fetchRoutes(String token) async => const [
    FleetRoute(routeId: 'R-1', name: 'Tcherassi', total: 2, online: 2),
  ];
}

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

Future<void> _cargarFuentes() async {
  final manifiesto =
      json.decode(await rootBundle.loadString('FontManifest.json'))
          as List<dynamic>;
  for (final entrada in manifiesto.cast<Map<String, dynamic>>()) {
    final cargador = FontLoader(entrada['family'] as String);
    final fuentes = (entrada['fonts'] as List).cast<Map<String, dynamic>>();
    for (final fuente in fuentes) {
      cargador.addFont(rootBundle.load(fuente['asset'] as String));
    }
    await cargador.load();
  }
}

/// La tarjeta de cada bus, tal como está montada ahora.
Map<String, FleetListTile> _tarjetas(WidgetTester tester) => {
  for (final t in tester.widgetList<FleetListTile>(find.byType(FleetListTile)))
    t.bus.busId: t,
};

/// Dónde pinta el mapa cada bus (los marcadores no se identifican por bus:
/// basta con el conjunto de latitudes).
Set<double> _latitudesEnElMapa(WidgetTester tester) => {
  for (final capa in tester.widgetList<MarkerLayer>(find.byType(MarkerLayer)))
    for (final m in capa.markers) m.point.latitude,
};

void main() {
  setUpAll(_cargarFuentes);

  // Lo que decide si el dashboard se rehace. Por el socket `online` e
  // `isGhost` cambian juntos, así que la prueba de abajo no distingue si
  // falta uno: aquí va campo por campo.
  test('mismaFicha: la posición no cuenta, lo que pinta la lista sí', () {
    const base = FleetBus(
      busId: 'B-1',
      companyId: 'c-1',
      routeId: 'R-1',
      placa: 'ABC123',
      interno: '7',
      driverName: 'Ana',
      visible: true,
      online: true,
      lat: 10.98,
      lon: -74.8,
      heading: 90,
      speedKmh: 20,
      capturedAt: 1,
      receivedAt: 2,
      sequence: 3,
    );
    final soloPosicion = base.copyWith(
      lat: 11,
      lon: -75,
      heading: 180,
      speedKmh: 40,
      capturedAt: 10,
      receivedAt: 20,
      sequence: 30,
    );
    expect(base.mismaFicha(soloPosicion), isTrue);

    final cambios = <String, FleetBus>{
      'companyId': const FleetBus(
        busId: 'B-1',
        companyId: 'c-2',
        routeId: 'R-1',
        placa: 'ABC123',
        interno: '7',
        driverName: 'Ana',
        visible: true,
        online: true,
      ),
      'placa': base.copyWith(placa: 'XYZ987'),
      'interno': base.copyWith(interno: '8'),
      'driverName': base.copyWith(driverName: 'Luis'),
      'routeId': base.copyWith(routeId: 'R-2'),
      'visible': base.copyWith(visible: false),
      'online': base.copyWith(online: false),
      'isGhost': base.copyWith(isGhost: true),
    };
    for (final MapEntry(key: campo, value: otro) in cambios.entries) {
      expect(base.mismaFicha(otro), isFalse, reason: campo);
    }
    expect(
      base.mismaFicha(
        const FleetBus(
          busId: 'B-2',
          companyId: 'c-1',
          visible: true,
          online: true,
        ).copyWith(
          routeId: 'R-1',
          placa: 'ABC123',
          interno: '7',
          driverName: 'Ana',
        ),
      ),
      isFalse,
      reason: 'busId',
    );
  });

  testWidgets(
    'una posición mueve el bus en el mapa sin rehacer ninguna tarjeta',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1600, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      late _FakeSocket socket;
      final container = ProviderContainer(
        overrides: [
          backendUrlProvider.overrideWith(
            () => BackendUrl.fija('http://localhost:3000'),
          ),
          fleetProvider.overrideWith(
            (ref) => FleetNotifier(ref, api: _FakeFleetApi()),
          ),
          fleetSocketFactoryProvider.overrideWithValue(
            (_) => socket = _FakeSocket(),
          ),
        ],
      );
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
          child: MaterialApp(
            theme: AppTheme.light,
            home: const DashboardScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final antes = _tarjetas(tester);
      expect(antes.keys, unorderedEquals(['B-1', 'B-2']));

      // El filo entre buses va centrado en la barra (dueño, 2026-10-07).
      final filo = tester.widget<Divider>(
        find.descendant(
          of: find.byType(ListView),
          matching: find.byType(Divider),
        ),
      );
      expect(filo.indent, filo.endIndent, reason: 'filo centrado');

      // Solo se mueve: la lista no enseña nada de esto.
      socket.posiciones.add(
        const FleetBus(
          busId: 'B-1',
          companyId: 'c-1',
          routeId: 'R-1',
          visible: true,
          online: true,
          lat: 11.01,
          lon: -74.7,
          speedKmh: 32,
          capturedAt: 2000,
        ),
      );
      // Un segundo cuadro: el mapa repinta sus marcadores en el siguiente.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        _latitudesEnElMapa(tester),
        contains(11.01),
        reason: 'el mapa sí se entera',
      );
      final despues = _tarjetas(tester);
      expect(
        identical(despues['B-1'], antes['B-1']),
        isTrue,
        reason: 'la tarjeta del bus que se movió no se rehace',
      );
      expect(
        identical(despues['B-2'], antes['B-2']),
        isTrue,
        reason: 'ni la de los demás',
      );

      // Deja de reportar: eso sí se ve en su tarjeta.
      socket.posiciones.add(
        const FleetBus(
          busId: 'B-1',
          companyId: 'c-1',
          routeId: 'R-1',
          visible: true,
          online: true,
          lat: 11.01,
          lon: -74.7,
          capturedAt: 2000,
          isGhost: true,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // El ícono de «Inactivo» (`BusEstado.icono`) en su fila, no en la otra.
      final fila = find.ancestor(
        of: find.text('ABC123'),
        matching: find.byType(FleetListTile),
      );
      final otra = find.ancestor(
        of: find.text('XYZ987'),
        matching: find.byType(FleetListTile),
      );
      final inactivo = find.byIcon(Icons.pause_circle_outline);
      expect(find.descendant(of: fila, matching: inactivo), findsOneWidget);
      expect(find.descendant(of: otra, matching: inactivo), findsNothing);
      expect(tester.takeException(), isNull);

      // Como `_desmontar` de teclado_panel_test.dart: el contenedor se cierra
      // antes del último pump para que no quede vivo el latido de resincronía.
      await tester.pumpWidget(const SizedBox());
      container.dispose();
      await tester.pump(const Duration(seconds: 2));
    },
  );

  // La ficha del bus seleccionado dice a qué va (`VelocidadBus`) y cuándo se
  // supo de él (`UltimoReporte`). Eso cambia con cada posición, así que va en
  // su propio pedazo: la posición lo actualiza a él y la lista sigue sin
  // rehacerse.
  testWidgets('la ficha del bus seleccionado sigue su último reporte', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1600, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    late _FakeSocket socket;
    final container = ProviderContainer(
      overrides: [
        backendUrlProvider.overrideWith(
          () => BackendUrl.fija('http://localhost:3000'),
        ),
        fleetProvider.overrideWith(
          (ref) => FleetNotifier(ref, api: _FakeFleetApi()),
        ),
        fleetSocketFactoryProvider.overrideWithValue(
          (_) => socket = _FakeSocket(),
        ),
      ],
    );
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
        child: MaterialApp(
          theme: AppTheme.light,
          home: const DashboardScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    container.read(fleetProvider.notifier).selectBus('B-1');
    await tester.pump();
    final antes = _tarjetas(tester);

    socket.posiciones.add(
      FleetBus(
        busId: 'B-1',
        companyId: 'c-1',
        routeId: 'R-1',
        visible: true,
        online: true,
        lat: 11.01,
        lon: -74.7,
        speedKmh: 32,
        capturedAt: 2000,
        receivedAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    // Como arriba: el evento entra en un cuadro y se pinta en el siguiente.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final ficha = find.byType(VelocidadBus);
    expect(
      find.descendant(of: ficha, matching: find.text('32')),
      findsOneWidget,
    );
    expect(find.text('Último reporte ahora'), findsOneWidget);
    expect(
      identical(_tarjetas(tester)['B-1'], antes['B-1']),
      isTrue,
      reason: 'la lista sigue sin rehacerse',
    );

    // Callado: la ficha lo dice y la velocidad vieja ya no se enseña.
    socket.posiciones.add(
      FleetBus(
        busId: 'B-1',
        companyId: 'c-1',
        routeId: 'R-1',
        visible: true,
        online: true,
        lat: 11.01,
        lon: -74.7,
        speedKmh: 32,
        capturedAt: 3000,
        receivedAt: DateTime.now().millisecondsSinceEpoch,
        isGhost: true,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Último reporte ahora'), findsOneWidget);
    expect(find.descendant(of: ficha, matching: find.text('32')), findsNothing);
    expect(
      find.descendant(of: ficha, matching: find.text('—')),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox());
    container.dispose();
    await tester.pump(const Duration(seconds: 2));
  });
}
