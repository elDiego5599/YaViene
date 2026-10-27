// El retoque visual del panel (2026-09-28): lo que el dueño ve, medido.
//
// El panel ya era confiable; lo que se pulió es el aspecto, y cada cambio
// deja aquí la medida que lo sostiene, para que un retoque futuro no lo
// deshaga sin darse cuenta:
//
// - Las filas de la lista eran tarjetas con borde dentro de la tarjeta con
//   borde de la lista. Ahora son filas planas; solo la elegida lleva marco.
// - «PERMITIDO»/«OCULTO» iba a 8 pt, por debajo de lo que se lee en un
//   proyector.
// - «Agregar bus» heredaba los 52 de alto del botón de entrar y pesaba más
//   que la lista que encabeza.
// - Las pestañas de estado flotaban sueltas: ahora van en su carril, como
//   un control segmentado de macOS.
// - Actualizar y mostrar/ocultar todos eran dos círculos sueltos junto a
//   un buscador rectangular: ahora son una barra del alto del buscador.
// - El mapa era el único bloque con esquinas rectas.
// - En la ficha, lápiz y papelera eran círculos junto a un botón
//   rectangular de 40: ahora son cuadrados de 40 con el mismo radio.
// - Y la ventana ya no se deja achicar por debajo de lo que se cuida
//   (panel_angosto_test.dart): a 1024 la placa se encogía a 8 px.
//
// Con la tipografía de la app, como panel_angosto_test.dart.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_control/core/theme/app_theme.dart';
import 'package:ya_viene_control/core/widgets/ventana_minima.dart'
    show ventanaMinima;
import 'package:ya_viene_control/features/auth/domain/auth_session.dart';
import 'package:ya_viene_control/features/auth/presentation/providers/auth_providers.dart';
import 'package:ya_viene_control/features/fleet/data/fleet_api.dart';
import 'package:ya_viene_control/features/fleet/data/fleet_socket_service.dart';
import 'package:ya_viene_control/features/fleet/domain/fleet_bus.dart';
import 'package:ya_viene_control/features/fleet/domain/fleet_route.dart';
import 'package:ya_viene_control/features/fleet/presentation/providers/fleet_providers.dart';
import 'package:ya_viene_control/features/fleet/presentation/screens/dashboard_screen.dart';
import 'package:ya_viene_control/features/fleet/presentation/widgets/control_map.dart';
import 'package:ya_viene_control/features/fleet/presentation/widgets/fleet_list_tile.dart';
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
      visible: false,
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

/// Monta el dashboard a [tam], corre [revisar] y lo desmonta dentro de la
/// prueba: el refresco de cada minuto tiene que quedar cancelado antes de
/// que `flutter test` busque temporizadores pendientes.
Future<void> _conPanel(
  WidgetTester tester,
  Size tam,
  Future<void> Function(ProviderContainer container) revisar,
) async {
  await tester.binding.setSurfaceSize(tam);
  addTearDown(() => tester.binding.setSurfaceSize(null));
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

  await revisar(container);

  await tester.pumpWidget(const SizedBox());
  container.dispose();
  await tester.pump(const Duration(seconds: 2));
}

/// El borde que pinta la fila de [placa], o null si no pinta ninguno.
BoxBorder? _bordeDeFila(WidgetTester tester, String placa) {
  final caja = tester.widget<Container>(
    find
        .descendant(
          of: find.ancestor(
            of: find.text(placa),
            matching: find.byType(FleetListTile),
          ),
          matching: find.byWidgetPredicate(
            (w) => w is Container && w.decoration is BoxDecoration,
          ),
        )
        .first,
  );
  final borde = (caja.decoration! as BoxDecoration).border;
  if (borde is Border && borde.top.color.a == 0) return null;
  return borde;
}

Finder _botonConTooltip(String tooltip) => find.ancestor(
  of: find.byTooltip(tooltip),
  matching: find.byType(IconButton),
);

/// Lo que mide lo pintado de un botón: su Material. El botón entero puede
/// medir más, porque en la plataforma de las pruebas (Android) se le suma
/// el blanco táctil de 48; en macOS y Windows, donde corre el panel, no.
Size _pintado(WidgetTester tester, Finder boton) => tester.getSize(
  find.descendant(of: boton, matching: find.byType(Material)).first,
);

void main() {
  setUpAll(_cargarFuentes);

  testWidgets('las filas son planas: solo la elegida lleva marco', (
    tester,
  ) async {
    await _conPanel(tester, const Size(1440, 900), (container) async {
      expect(
        _bordeDeFila(tester, 'ABC123'),
        isNull,
        reason: 'volvió la tarjeta dentro de la tarjeta',
      );
      container.read(fleetProvider.notifier).selectBus('B-1');
      await tester.pump();
      expect(
        _bordeDeFila(tester, 'ABC123'),
        isNotNull,
        reason: 'la fila elegida se tiene que ver elegida',
      );
      expect(_bordeDeFila(tester, 'XYZ987'), isNull);
    });
  });

  testWidgets('«PERMITIDO» y «OCULTO» se leen: 9 pt o más', (tester) async {
    await _conPanel(tester, const Size(1440, 900), (_) async {
      for (final rotulo in ['PERMITIDO', 'OCULTO']) {
        final estilo = tester.widget<Text>(find.text(rotulo)).style!;
        expect(estilo.fontSize, greaterThanOrEqualTo(9), reason: rotulo);
      }
    });
  });

  testWidgets('«Agregar bus» es un botón de cabecera, no el de entrar', (
    tester,
  ) async {
    await _conPanel(tester, const Size(1440, 900), (_) async {
      final boton = find.ancestor(
        of: find.text('Agregar bus'),
        matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
      );
      expect(_pintado(tester, boton).height, lessThanOrEqualTo(40));
    });
  });

  testWidgets('las pestañas de estado van en su carril', (tester) async {
    await _conPanel(tester, const Size(1440, 900), (_) async {
      final carril = find.ancestor(
        of: find.text('Todos'),
        matching: find.byKey(const ValueKey('carril-estados')),
      );
      expect(carril, findsOneWidget);
      for (final pestana in ['En Línea', 'Ocultos', 'Sin Señal']) {
        expect(
          find.descendant(of: carril, matching: find.text(pestana)),
          findsOneWidget,
          reason: pestana,
        );
      }
    });
  });

  testWidgets('actualizar y mostrar/ocultar todos: una barra del alto del '
      'buscador, con botones cuadrados', (tester) async {
    await _conPanel(tester, const Size(1440, 900), (_) async {
      // 48 y no «lo que mida el campo»: los dos van en un IntrinsicHeight,
      // así que si la barra creciera estiraría también la caja del campo y
      // compararlas no diría nada. 48 es lo que mide el campo solo, con la
      // letra a 1× (el tema: 10 de relleno por lado y la línea de 13,5).
      final buscador = tester.getRect(find.byType(TextField).first);
      final barra = tester.getRect(find.byKey(const ValueKey('barra-flota')));
      expect(barra.height, closeTo(48, 0.5));
      expect(buscador.height, closeTo(48, 0.5));
      expect(barra.center.dy, closeTo(buscador.center.dy, 0.5));
      // B-2 está oculto, así que el segundo ofrece mostrarlos todos.
      // Actualizar subió a la cabecera (dueño, 2026-10-26): en la barra solo
      // queda mostrar u ocultar todos.
      for (final tooltip in ['Mostrar todos los buses']) {
        final boton = _botonConTooltip(tooltip);
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('barra-flota')),
            matching: boton,
          ),
          findsOneWidget,
          reason: tooltip,
        );
        final forma = tester
            .widget<IconButton>(boton)
            .style!
            .shape!
            .resolve({});
        expect(forma, isA<RoundedRectangleBorder>(), reason: tooltip);
      }
      final actualizar = find.byKey(const ValueKey('actualizar'));
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('cabecera')),
          matching: actualizar,
        ),
        findsOneWidget,
      );
      // Cuadrado de 36, del alto de Salir.
      expect(tester.getSize(actualizar), const Size(36, 36));
    });
  });

  testWidgets('el mapa tiene las esquinas de la lista', (tester) async {
    await _conPanel(tester, const Size(1440, 900), (_) async {
      final recorte = tester.widget<ClipRRect>(
        find
            .ancestor(
              of: find.byType(ControlMap),
              matching: find.byType(ClipRRect),
            )
            .first,
      );
      expect(recorte.borderRadius, BorderRadius.circular(AppRadius.lg));
    });
  });

  testWidgets('en la ficha, lápiz y papelera miden y redondean como '
      '«Ocultar»', (tester) async {
    await _conPanel(tester, const Size(1440, 900), (container) async {
      container.read(fleetProvider.notifier).selectBus('B-1');
      await tester.pump();

      final ocultar = _pintado(
        tester,
        find.ancestor(
          of: find.text('Ocultar'),
          matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
        ),
      );
      // El lápiz de la ficha: el último, el de la fila va antes en el árbol.
      for (final boton in [
        _botonConTooltip('Editar bus').last,
        _botonConTooltip('Eliminar bus de la flota'),
      ]) {
        final tam = _pintado(tester, boton);
        expect(tam.height, closeTo(ocultar.height, 0.5));
        expect(tam.width, closeTo(tam.height, 0.5));
        final forma = tester
            .widget<IconButton>(boton)
            .style!
            .shape!
            .resolve({});
        expect(
          forma,
          isA<RoundedRectangleBorder>().having(
            (f) => f.borderRadius,
            'radio',
            BorderRadius.circular(AppRadius.md),
          ),
        );
      }
    });
  });

  testWidgets('la ventana no baja de lo que se cuida', (tester) async {
    // panel_angosto_test.dart prueba de 1600 a 1200; por debajo, a 1024, la
    // placa de la lista se encogía a 8 px.
    expect(ventanaMinima.width, 1200);
    await _conPanel(tester, ventanaMinima, (container) async {
      expect(tester.takeException(), isNull);
      container.read(fleetProvider.notifier).selectBus('B-1');
      await tester.pump();
      expect(tester.takeException(), isNull, reason: 'con la ficha abierta');
    });
  });
}
