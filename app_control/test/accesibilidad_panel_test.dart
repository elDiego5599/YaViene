// El panel se entiende con lector de pantalla (T6.1).
//
// Con VoiceOver o Narrador, el mapa era un botón sin nombre; cada fila de la
// lista se leía a pedazos (placa, estado, ruta, «PERMITIDO») sin decir que
// eran del mismo bus; el ojo de la contraseña decía solo «Mostrar», y el
// diálogo de agregar bus abría sin foco en ningún campo. Y el gris de los
// rótulos pequeños (#94A3B8 sobre la arena) daba 2,4:1, lejos del 4,5:1 que
// pide el texto normal: ahora es el mismo gris que usa la app del pasajero.
//
// Las guías de Flutter revisan cada pantalla: todo lo que se toca tiene
// nombre y todo texto tiene contraste. Se corren con la tipografía de la app,
// como teclado_panel_test.dart.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

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
import 'package:ya_viene_control/main.dart';
import 'package:ya_viene_core/core/providers/app_providers.dart'
    show BackendUrl, backendUrlProvider;

class _FakeFleetApi extends FleetApi {
  _FakeFleetApi() : super(baseUrl: 'http://localhost:3000');

  final flota = <FleetBus>[
    const FleetBus(
      busId: 'B-1', companyId: 'c-1', routeId: 'R-1', placa: 'ABC-123',
      visible: true, online: true, lat: 10.98, lon: -74.8,
    ),
    const FleetBus(
      busId: 'B-2', companyId: 'c-1', routeId: 'R-1', placa: 'XYZ-987',
      visible: true, online: true, lat: 10.99, lon: -74.81,
    ),
  ];

  @override
  Future<List<FleetBus>> fetchPositions(String token) async => [...flota];

  @override
  Future<List<FleetRoute>> fetchRoutes(String token) async =>
      const [FleetRoute(routeId: 'R-1', name: 'Tcherassi', total: 2, online: 2)];
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

ProviderContainer? _contenedor;

Future<void> _montar(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(1600, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final container = ProviderContainer(
    overrides: [
      backendUrlProvider.overrideWith(() => BackendUrl.fija('http://localhost:3000')),
      fleetProvider.overrideWith((ref) => FleetNotifier(ref, api: _FakeFleetApi())),
      fleetSocketFactoryProvider.overrideWithValue((_) => _FakeSocket()),
    ],
  );
  container.read(authProvider.notifier).state = const AuthState(
    status: AuthStatus.authenticated,
    session: AuthSession(token: 'tok', companyId: 'c-1', companyName: 'Empresa 1'),
  );
  _contenedor = container;
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp(theme: AppTheme.light, home: const DashboardScreen()),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> _desmontar(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  _contenedor?.dispose();
  await tester.pump(const Duration(seconds: 2));
}

Future<void> _cargarFuentes() async {
  final manifiesto = json.decode(
    await rootBundle.loadString('FontManifest.json'),
  ) as List<dynamic>;
  for (final entrada in manifiesto.cast<Map<String, dynamic>>()) {
    final cargador = FontLoader(entrada['family'] as String);
    final fuentes = (entrada['fonts'] as List).cast<Map<String, dynamic>>();
    for (final fuente in fuentes) {
      cargador.addFont(rootBundle.load(fuente['asset'] as String));
    }
    await cargador.load();
  }
}

/// Todo lo que se toca tiene nombre, y todo texto se lee sobre su fondo.
Future<void> _guias(WidgetTester tester) async {
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  await expectLater(tester, meetsGuideline(textContrastGuideline));
}

void main() {
  setUpAll(_cargarFuentes);

  // Las guías dejan correr lo asíncrono de verdad, y ahí el caché de teselas
  // de flutter_map pide su carpeta al sistema; en pruebas no hay quien
  // conteste. Se le da una temporal.
  late Directory cache;
  setUpAll(() {
    cache = Directory.systemTemp.createTempSync('panel-a11y-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (_) async => cache.path,
    );
  });
  tearDownAll(() => cache.deleteSync(recursive: true));

  testWidgets('el dashboard: cada bus se lee entero y el mapa tiene nombre',
      (tester) async {
    final semantica = tester.ensureSemantics();
    await _montar(tester);

    expect(
      find.bySemanticsLabel('Placa ABC-123, En línea, ruta Tcherassi'),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Mapa de la flota'), findsOneWidget);
    await _guias(tester);

    await _desmontar(tester);
    semantica.dispose();
  });

  testWidgets('«Agregar bus» abre con el foco en la placa', (tester) async {
    final semantica = tester.ensureSemantics();
    await _montar(tester);

    await tester.tap(find.text('Agregar bus'));
    await tester.pumpAndSettle();
    final foco = FocusManager.instance.primaryFocus?.context;
    expect(foco?.findAncestorWidgetOfExactType<TextField>(), isNotNull);
    await _guias(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    await _desmontar(tester);
    semantica.dispose();
  });

  testWidgets('los diálogos de rutas y de editar bus pasan las guías',
      (tester) async {
    final semantica = tester.ensureSemantics();
    await _montar(tester);

    await tester.tap(find.text('Agregar ruta'));
    await tester.pumpAndSettle();
    await _guias(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Editar bus').first);
    await tester.pumpAndSettle();
    await _guias(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    await _desmontar(tester);
    semantica.dispose();
  });

  testWidgets('el login dice qué muestra el ojo y se lee sobre la arena',
      (tester) async {
    final semantica = tester.ensureSemantics();
    await tester.binding.setSurfaceSize(const Size(1366, 768));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(ProviderScope(
      overrides: [
        backendUrlProvider.overrideWith(
            () => BackendUrl.fija('http://localhost:3000')),
      ],
      child: const YaVieneControlApp(),
    ));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Mostrar contraseña'), findsOneWidget);
    await tester.tap(find.byTooltip('Mostrar contraseña'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Ocultar contraseña'), findsOneWidget);
    await _guias(tester);

    semantica.dispose();
  });
}
