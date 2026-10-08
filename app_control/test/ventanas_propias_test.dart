import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_control/core/theme/app_theme.dart';
import 'package:ya_viene_control/core/widgets/ventana.dart';
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

/// Las ventanas y los avisos del panel son los suyos (dueño, 2026-09-28:
/// «los pop ups y warning en todas las apps deben ser con diseño propio,
/// por ejemplo el de revocacion de sesion en la app de control»).
///
/// Todo lo que el panel abre encima del tablero pasa por `Ventana` y todo
/// aviso corto por `AvisoPanel` (lib/core/widgets/ventana.dart). La última
/// prueba lee `lib/` entero: un `AlertDialog` o un `SnackBar` de fábrica
/// nuevo sale rojo aquí, no en la mesa del dueño. El arnés es el de
/// `estados_vacios_test.dart`.
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
  Future<List<FleetBus>> fetchPositions(String? token) async {
    if (expirar) throw const SessionExpiredException();
    return [...buses];
  }

  @override
  Future<List<FleetRoute>> fetchRoutes(String? token) async => [...rutas];

  /// El backend no deja borrar: la confirmación pasa y el aviso cuenta el
  /// fallo.
  @override
  Future<void> deleteBus(String? token, String busId) async =>
      throw Exception('500');
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

/// Monta el dashboard con el arnés de `estados_vacios_test.dart`.
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

  Future<void> tecla(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyEvent(key);
    await tester.pumpAndSettle();
  }

  Finder ventana(String titulo) =>
      find.ancestor(of: find.text(titulo), matching: find.byType(Ventana));

  testWidgets('la sesión revocada sale en la ventana del panel y solo se '
      'va con su botón', (tester) async {
    final (container, api) = await _montar(tester);

    api.expirar = true;
    await container.read(fleetProvider.notifier).refresh();
    await tester.pumpAndSettle();

    expect(ventana('Tu sesión expiró'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('INICIAR SESIÓN'), findsOneWidget);

    // Ni el clic fuera ni Esc: la única salida es volver a entrar.
    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();
    await tecla(tester, LogicalKeyboardKey.escape);
    expect(ventana('Tu sesión expiró'), findsOneWidget);

    await _desmontar(tester);
  });

  testWidgets('Agregar bus abre la ventana del panel y Esc la cierra', (
    tester,
  ) async {
    await _montar(tester);

    await tester.tap(find.text('Agregar bus'));
    await tester.pumpAndSettle();
    expect(ventana('Nuevo bus'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('AGREGAR'), findsOneWidget);

    await tecla(tester, LogicalKeyboardKey.escape);
    expect(find.byType(Ventana), findsNothing);
    await _desmontar(tester);
  });

  testWidgets('el catálogo de rutas, renombrar y eliminar son ventanas del '
      'panel', (tester) async {
    await _montar(tester);

    await tester.tap(find.text('Agregar ruta'));
    await tester.pumpAndSettle();
    expect(ventana('Rutas'), findsOneWidget);

    await tester.tap(find.byTooltip('Renombrar ruta'));
    await tester.pumpAndSettle();
    expect(ventana('Renombrar ruta'), findsOneWidget);
    expect(
      find.descendant(
        of: ventana('Renombrar ruta'),
        matching: find.byType(TextField),
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Eliminar ruta'));
    await tester.pumpAndSettle();
    expect(ventana('Eliminar ruta'), findsOneWidget);
    expect(
      tester.widget<Ventana>(ventana('Eliminar ruta')).tono,
      VentanaTono.peligro,
    );
    expect(find.byType(AlertDialog), findsNothing);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(ventana('Rutas'), findsOneWidget);

    await _desmontar(tester);
  });

  testWidgets('borrar el bus pregunta en rojo y, si falla, avisa en la '
      'tarjeta del panel', (tester) async {
    final (container, _) = await _montar(tester);
    container.read(fleetProvider.notifier).selectBus('B-1');
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Eliminar bus de la flota'));
    await tester.pumpAndSettle();
    expect(ventana('Eliminar bus'), findsOneWidget);
    expect(
      tester.widget<Ventana>(ventana('Eliminar bus')).tono,
      VentanaTono.peligro,
    );

    await tester.tap(find.text('ELIMINAR'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      find.descendant(
        of: find.byType(AvisoPanel),
        matching: find.text('No se pudo eliminar el bus.'),
      ),
      findsOneWidget,
    );
    // El SnackBar solo presta la cola: su fondo es transparente y sin
    // sombra; lo que se ve es la tarjeta.
    final barra = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(barra.backgroundColor, Colors.transparent);
    expect(barra.elevation, 0);

    await _desmontar(tester);
  });

  test('ningún archivo de lib/ abre un diálogo o un aviso de fábrica', () {
    final fuera = <String>[];
    final fabrica = RegExp(r'\bAlertDialog\(|\bshowDialog\b|\bSimpleDialog\(');
    final barra = RegExp(r'\bSnackBar\(');
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final texto = f.readAsStringSync();
      if (fabrica.hasMatch(texto)) fuera.add(f.path);
      // El único SnackBar es el que presta su cola a `AvisoPanel`.
      if (barra.hasMatch(texto) && !f.path.endsWith('ventana.dart')) {
        fuera.add(f.path);
      }
    }
    expect(fuera, isEmpty);
  });

  // El globo del Tooltip también es un «pop up»: salía en el gris de
  // fábrica con esquinas de 4, lo único de la pantalla que no era de la
  // app.
  testWidgets(
    'el globo de ayuda va en el azul de la consola, no en el gris de fábrica',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: Center(
              child: Tooltip(message: 'Hola', child: Text('x')),
            ),
          ),
        ),
      );
      await tester.longPress(find.text('x'));
      await tester.pumpAndSettle();

      final globo = tester.widget<Container>(
        find
            .ancestor(of: find.text('Hola'), matching: find.byType(Container))
            .first,
      );
      final fondo = globo.decoration! as BoxDecoration;
      expect(fondo.color, AppColors.navy);
      expect(fondo.borderRadius, isNot(BorderRadius.circular(4)));
    },
  );
}
