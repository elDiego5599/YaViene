// El panel en las ventanas de verdad, no solo en la de 1600 de las demás
// pruebas.
//
// La lista de buses es un cuarto del ancho y su cabecera llevaba «BUSES»,
// «Agregar ruta» y «Agregar bus» en la misma fila. A 1440 —la pantalla de
// un MacBook Air— ese cuarto son 349 px y la fila pide unos 376: el botón
// verde salía cortado contra el borde. Y las cuatro pestañas de estado
// («Todos», «En Línea», «Ocultos», «Sin Señal») se cortaban igual a 1280,
// una pantalla de 1920 con Windows al 150 %.
//
// Se monta el dashboard entero desde 1600 hasta 1200, el ancho más chico
// que ya cuida fleet_list_tile_test.dart, y se pide lo que pide cualquier
// ventana: que nada se desborde, y que «Agregar ruta» y «Agregar bus» sigan
// ahí con ese nombre. Y lo mismo con la ficha de un bus abierta. Con la tipografía de la app, como
// teclado_panel_test.dart: con la de pruebas los anchos no son los reales.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:ya_viene_core/core/providers/app_providers.dart'
    show BackendUrl, backendUrlProvider;

class _FakeFleetApi extends FleetApi {
  _FakeFleetApi() : super(baseUrl: 'http://localhost:3000');

  @override
  Future<List<FleetBus>> fetchPositions(String? token) async => const [
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

  @override
  Future<List<FleetRoute>> fetchRoutes(String? token) async => const [
    FleetRoute(routeId: 'R-1', name: 'Tcherassi', total: 2, online: 2),
  ];
}

class _FakeSocket extends FleetSocketService {
  _FakeSocket() : super(baseUrl: 'http://localhost:3000', token: 'tok');

  @override
  void connect() {}
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

/// Monta el dashboard a [tam] con la letra a [escala], lo revisa y lo
/// desmonta. Si algo se desborda, Flutter lo reporta como excepción.
Future<void> _revisarA(
  WidgetTester tester,
  Size tam, {
  double escala = 1,
}) async {
  final donde = '${tam.width.toInt()} px a $escala×';
  await tester.binding.setSurfaceSize(tam);
  tester.platformDispatcher.textScaleFactorTestValue = escala;
  final container = ProviderContainer(
    overrides: [
      backendUrlProvider.overrideWith(
        () => BackendUrl.fija('http://localhost:3000'),
      ),
      fleetProvider.overrideWith(
        (ref) => FleetNotifier(ref, api: _FakeFleetApi()),
      ),
      fleetSocketFactoryProvider.overrideWithValue((_) => _FakeSocket()),
    ],
  );
  container.read(authProvider.notifier).state = const AuthState(
    status: AuthStatus.authenticated,
    session: AuthSession(token: 'tok', companyId: 'c-1', companyName: 'Sobusa'),
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(theme: AppTheme.light, home: const DashboardScreen()),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));

  expect(tester.takeException(), isNull, reason: donde);
  // Ni el recuadro de latencia de depuración, que se pide al compilar
  // (ver `RecuadroLatencia.pedido`) y si no, tapa el mapa.
  expect(find.text('latencia (depuración)'), findsNothing);
  for (final accion in ['Agregar ruta', 'Agregar bus']) {
    expect(
      find.bySemanticsLabel(accion),
      findsOneWidget,
      reason: '«$accion» a $donde',
    );
  }

  // Con un bus abierto en su ficha, que se monta encima del mapa. Ni la
  // ficha ni la fila dicen el conductor: el de la flota de ejemplo
  // («Conductor 3001») no le decía nada al operador y el dueño lo quitó.
  container.read(fleetProvider.notifier).selectBus('B-1');
  await tester.pump();
  expect(tester.takeException(), isNull, reason: 'ficha a $donde');
  expect(find.textContaining('Ana Pérez'), findsNothing, reason: donde);

  await tester.pumpWidget(const SizedBox());
  container.dispose();
  await tester.pump(const Duration(seconds: 2));
  tester.platformDispatcher.clearTextScaleFactorTestValue();
}

void main() {
  setUpAll(_cargarFuentes);

  // 1536 es una pantalla de 1920 con Windows al 125 %, 1366 un portátil
  // corriente, 1200 una ventana achicada a mano.
  for (final ancho in const [1600.0, 1536.0, 1440.0, 1366.0, 1280.0, 1200.0]) {
    testWidgets('a ${ancho.toInt()} px nada se desborda', (tester) async {
      final semantica = tester.ensureSemantics();
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await _revisarA(tester, Size(ancho, 800));
      semantica.dispose();
    });
  }

  // Con la letra del sistema grande. `main.dart` la recorta a 2×
  // (escalado_texto_test.dart), y ahí ya estaba probada la cabecera sola,
  // no el panel entero: las pestañas de estado, «Agregar ruta» al final de
  // las rutas y la ficha del bus son de después. A 1366, un portátil
  // corriente, y a 1200, la ventana más chica que se cuida.
  for (final escala in const [1.5, 2.0]) {
    for (final ancho in const [1366.0, 1200.0]) {
      testWidgets('a ${ancho.toInt()} px y letra a $escala× nada se desborda', (
        tester,
      ) async {
        final semantica = tester.ensureSemantics();
        addTearDown(() => tester.binding.setSurfaceSize(null));
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await _revisarA(tester, Size(ancho, 800), escala: escala);
        semantica.dispose();
      });
    }
  }
}
