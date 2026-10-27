// El panel se maneja con el teclado (T6.2).
//
// El panel es de escritorio, y ahí hay quien no suelta el teclado. Tab
// recorría la lista en un orden que no seguía a nadie: la pestaña «Todos»,
// los dos buses, «En Línea», «Agregar ruta», «Ocultos», los dos lápices, los
// dos interruptores… La política por omisión ordena por filas de pantalla y
// aquí las filas no están alineadas. Ahora el dashboard recorre en el orden
// del árbol: cabecera, barra de arriba, filtros de ruta, botones de la
// lista, pestañas, y cada bus con su lápiz y su interruptor antes del
// siguiente; luego el mapa, y de ahí vuelve arriba, sin trampas.
//
// Además: Cmd+F (Ctrl+F en Windows) lleva a la búsqueda, Esc la vacía, y
// Esc cierra los diálogos.
//
// Con la tipografía de la app, como fleet_list_tile_test.dart: con Ahem el
// dashboard desborda a 1600 sin que la app lo haga.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_control/core/theme/app_theme.dart';
import 'package:ya_viene_control/core/widgets/ventana.dart';
import 'package:ya_viene_control/features/auth/domain/auth_session.dart';
import 'package:ya_viene_control/features/auth/presentation/providers/auth_providers.dart';
import 'package:ya_viene_control/features/fleet/data/fleet_api.dart';
import 'package:ya_viene_control/features/fleet/data/fleet_socket_service.dart';
import 'package:ya_viene_control/features/fleet/domain/fleet_bus.dart';
import 'package:ya_viene_control/features/fleet/domain/fleet_route.dart';
import 'package:ya_viene_control/features/fleet/presentation/providers/fleet_providers.dart';
import 'package:ya_viene_control/features/fleet/presentation/providers/reportes_provider.dart';
import 'package:ya_viene_control/features/fleet/presentation/screens/dashboard_screen.dart';
import 'package:ya_viene_control/features/fleet/presentation/screens/reportes_screen.dart';
import 'package:ya_viene_control/features/fleet/presentation/widgets/fleet_list_tile.dart';
import 'package:ya_viene_core/core/providers/app_providers.dart'
    show BackendUrl, backendUrlProvider;

class _FakeFleetApi extends FleetApi {
  _FakeFleetApi() : super(baseUrl: 'http://localhost:3000');

  int cargas = 0;

  final flota = <FleetBus>[
    const FleetBus(
      busId: 'B-1',
      companyId: 'c-1',
      routeId: 'R-1',
      placa: 'ABC123',
      visible: true,
      online: true,
      lat: 10.98,
      lon: -74.8,
    ),
    const FleetBus(
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
  Future<List<FleetBus>> fetchPositions(String? token) async {
    cargas++;
    return [...flota];
  }

  @override
  Future<List<FleetRoute>> fetchRoutes(String? token) async => const [
    FleetRoute(routeId: 'R-1', name: 'Tcherassi', total: 2, online: 2),
  ];
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
_FakeSocket? _socket;
_FakeFleetApi? _api;

Future<void> _montar(
  WidgetTester tester, {
  List<Override> overrides = const [],
}) async {
  await tester.binding.setSurfaceSize(const Size(1600, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final container = ProviderContainer(
    overrides: [
      ...overrides,
      backendUrlProvider.overrideWith(
        () => BackendUrl.fija('http://localhost:3000'),
      ),
      fleetProvider.overrideWith(
        (ref) => FleetNotifier(ref, api: _api = _FakeFleetApi()),
      ),
      fleetSocketFactoryProvider.overrideWithValue(
        (_) => _socket = _FakeSocket(),
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
  _contenedor = container;
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(theme: AppTheme.light, home: const DashboardScreen()),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> _desmontar(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  _contenedor?.dispose();
  await tester.pump(const Duration(seconds: 2));
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

/// Qué tiene el foco, dicho como lo diría quien mira la pantalla.
String _foco() {
  final nodo = FocusManager.instance.primaryFocus;
  final ctx = nodo?.context;
  if (ctx == null) return '(nada)';
  if (nodo!.debugLabel == 'FlutterMap') return 'mapa';
  final campo = ctx.findAncestorWidgetOfExactType<TextField>();
  if (campo != null) return 'buscar';
  final fila = ctx.findAncestorWidgetOfExactType<FleetListTile>()?.bus.placa;
  final tip = ctx.findAncestorWidgetOfExactType<Tooltip>()?.message;
  if (tip != null &&
      tip != 'Cierra la sesión en todos los equipos con esta cuenta') {
    return fila == null ? tip : '$tip · $fila';
  }
  final textos = <String>[];
  void visitar(Element e) {
    final w = e.widget;
    if (w is Text && w.data != null) textos.add(w.data!);
    if (textos.isEmpty) e.visitChildren(visitar);
  }

  (ctx as Element).visitChildren(visitar);
  return textos.isEmpty ? '?' : textos.first;
}

const _escritorio = TargetPlatformVariant(<TargetPlatform>{
  TargetPlatform.macOS,
  TargetPlatform.windows,
});

Future<void> _tecla(WidgetTester tester, LogicalKeyboardKey tecla) async {
  await tester.sendKeyEvent(tecla);
  await tester.pumpAndSettle();
}

Future<void> _buscarAtajo(WidgetTester tester) async {
  final modificador = defaultTargetPlatform == TargetPlatform.macOS
      ? LogicalKeyboardKey.metaLeft
      : LogicalKeyboardKey.controlLeft;
  await tester.sendKeyDownEvent(modificador);
  await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
  await tester.sendKeyUpEvent(modificador);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(_cargarFuentes);

  testWidgets('Tab recorre el dashboard en orden y vuelve arriba', (
    tester,
  ) async {
    await _montar(tester);

    final recorrido = <String>[];
    for (var i = 0; i < 22; i++) {
      await _tecla(tester, LogicalKeyboardKey.tab);
      recorrido.add(_foco());
    }

    const vuelta = [
      'Flota',
      'Reportes',
      'Actualizar',
      'Salir',
      'buscar',
      'Ocultar todos los buses',
      'Tcherassi (2)',
      'Agregar ruta',
      'Agregar bus',
      'Todos',
      'En Línea',
      'Ocultos',
      'Sin Señal',
      'ABC123',
      'Editar bus · ABC123',
      'Los pasajeros pueden ver este bus · ABC123',
      'XYZ987',
      'Editar bus · XYZ987',
      'Los pasajeros pueden ver este bus · XYZ987',
      'mapa',
    ];
    expect(recorrido, [...vuelta, ...vuelta.take(2)]);
    expect(tester.takeException(), isNull);
    await _desmontar(tester);
  }, variant: _escritorio);

  // Flota y Reportes son dos pestañas de la cabecera (dueño, 2026-10-26):
  // Reportes ya no tapa el panel con su propia pantalla y su «Volver»; la
  // cabecera se queda y la flota sigue montada detrás, con su mapa.
  testWidgets('Actualizar va en la cabecera y pone al día flota y reportes', (
    tester,
  ) async {
    var consultas = 0;
    await _montar(
      tester,
      overrides: [
        reportesRutasProvider.overrideWith((ref, args) async {
          consultas++;
          return const <RutaBusquedas>[];
        }),
      ],
    );
    final cabecera = find.byKey(const ValueKey('cabecera'));
    final actualizar = find.descendant(
      of: cabecera,
      matching: find.byKey(const ValueKey('actualizar')),
    );
    expect(actualizar, findsOneWidget);
    // La barra de Flota ya no lo trae, ni el título «Flota»: solo la pestaña.
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('barra-flota')),
        matching: find.byIcon(Icons.refresh),
      ),
      findsNothing,
    );
    expect(find.text('Flota'), findsOneWidget);
    // El logo va solo, sin el cuadro gris detrás.
    final cajas = tester
        .widgetList<Container>(
          find.ancestor(
            of: find.descendant(
              of: cabecera,
              matching: find.byType(SvgPicture),
            ),
            matching: find.byType(Container),
          ),
        )
        .where((c) => c.key != const ValueKey('cabecera'))
        .where((c) => c.decoration != null);
    expect(cajas, isEmpty);

    final cargasFlota = _api!.cargas;
    await tester.tap(actualizar);
    await tester.pump(const Duration(seconds: 1));
    expect(_api!.cargas, greaterThan(cargasFlota));

    await tester.tap(find.byKey(const ValueKey('pestana-reportes')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    // «Hoy» solo en el periodo: el texto suelto de la izquierda se fue.
    expect(find.text('Hoy'), findsOneWidget);
    final antes = consultas;
    await tester.tap(actualizar);
    await tester.pump(const Duration(seconds: 1));
    expect(consultas, greaterThan(antes));

    // Solas: con Reportes abierto, las búsquedas nuevas se suman sin tocar.
    final quietas = consultas;
    await tester.pump(const Duration(seconds: 31));
    expect(consultas, greaterThan(quietas));
    expect(tester.takeException(), isNull);
    await _desmontar(tester);
  });

  testWidgets('Reportes es una pestaña: la cabecera se queda y Flota vuelve', (
    tester,
  ) async {
    await _montar(
      tester,
      overrides: [
        reportesRutasProvider.overrideWith(
          (ref, args) => Completer<List<RutaBusquedas>>().future,
        ),
      ],
    );

    bool elegida(String clave) => tester
        .getSemantics(find.byKey(ValueKey(clave)))
        .flagsCollection
        .isSelected
        .toBoolOrNull()!;

    expect(find.byType(ReportesScreen), findsNothing);
    expect(elegida('pestana-flota'), isTrue);
    expect(elegida('pestana-reportes'), isFalse);

    await tester.tap(find.byKey(const ValueKey('pestana-reportes')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(ReportesScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('cabecera')), findsOneWidget);
    expect(find.byKey(const ValueKey('volver-reportes')), findsNothing);
    expect(elegida('pestana-reportes'), isTrue);
    expect(find.text('buscar'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('pestana-flota')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(elegida('pestana-flota'), isTrue);
    expect(find.byKey(const ValueKey('barra-flota')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _desmontar(tester);
  });

  testWidgets(
    'un bus que llega después entra a Tab en su sitio de la lista',
    (tester) async {
      await _montar(tester);

      // Lo dieron de alta en otro panel: llega por el socket cuando la lista
      // ya está montada, y la lista lo pone primero.
      // El panel pide el catálogo al ver un bus que no conocía; el servidor
      // ya lo tiene.
      const nuevo = FleetBus(
        busId: 'B-0',
        companyId: 'c-1',
        routeId: 'R-1',
        placa: 'AAA000',
        visible: true,
        online: true,
        lat: 10.97,
        lon: -74.79,
      );
      _api!.flota.add(nuevo);
      _socket!.posiciones.add(nuevo);
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.text('AAA000')).dy,
        lessThan(tester.getTopLeft(find.text('ABC123')).dy),
      );

      final recorrido = <String>[];
      for (var i = 0; i < 17; i++) {
        await _tecla(tester, LogicalKeyboardKey.tab);
        recorrido.add(_foco());
      }
      expect(recorrido.sublist(12), [
        'Sin Señal',
        'AAA000',
        'Editar bus · AAA000',
        'Los pasajeros pueden ver este bus · AAA000',
        'ABC123',
      ]);
      await _desmontar(tester);
    },
    variant: _escritorio,
  );

  testWidgets('el atajo de buscar lleva a la búsqueda y Esc la vacía', (
    tester,
  ) async {
    await _montar(tester);

    await _buscarAtajo(tester);
    expect(_foco(), 'buscar');

    await tester.enterText(find.byType(TextField), 'ABC');
    await tester.pumpAndSettle();
    expect(find.text('XYZ987'), findsNothing);

    await _tecla(tester, LogicalKeyboardKey.escape);
    expect(find.text('XYZ987'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
    expect(_foco(), 'buscar');
    await _desmontar(tester);
  }, variant: _escritorio);

  testWidgets('Enter abre «Agregar bus» y Esc cierra el diálogo', (
    tester,
  ) async {
    await _montar(tester);

    for (var i = 0; i < 9; i++) {
      await _tecla(tester, LogicalKeyboardKey.tab);
    }
    expect(_foco(), 'Agregar bus');
    await _tecla(tester, LogicalKeyboardKey.enter);
    expect(find.byType(Ventana), findsOneWidget);

    await _tecla(tester, LogicalKeyboardKey.escape);
    expect(find.byType(Ventana), findsNothing);
    await _desmontar(tester);
  }, variant: _escritorio);

  // Lo activo ya no va lleno de azul (dueño, 2026-10-26, pulido general):
  // el filtro de ruta elegido lleva la cápsula verde de las pestañas Flota y
  // Reportes, el verde de la ruta en el mapa; la pestaña de estado elegida,
  // la lámina blanca del segmentado de macOS con la tinta encima.
  testWidgets('el filtro y la pestaña activos van sin azul lleno', (
    tester,
  ) async {
    await _montar(tester);
    Color? relleno(String texto) => tester
        .widget<Material>(
          find
              .ancestor(of: find.text(texto), matching: find.byType(Material))
              .first,
        )
        .color;
    Color? letra(String texto) =>
        tester.widget<Text>(find.text(texto)).style?.color;
    expect(relleno('Tcherassi (2)'), AppColors.capsula);
    expect(letra('Tcherassi (2)'), Colors.white);
    expect(relleno('Todos'), AppColors.surface);
    expect(letra('Todos'), AppColors.textPrimary);
    expect(relleno('En Línea'), Colors.transparent);
    expect(letra('En Línea'), AppColors.textSecondary);
    await _desmontar(tester);
  });
}
