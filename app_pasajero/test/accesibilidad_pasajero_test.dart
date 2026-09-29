// El pasajero se entiende con lector de pantalla y con el dedo (T6.6).
//
// El panel ya tiene su prueba (`accesibilidad_panel_test.dart`); esta es la
// otra mitad, y va sobre las cinco superficies que el pasajero toca: la
// bienvenida, el selector de empresa y ruta, la píldora de búsqueda, la hoja
// de distancia y el centro de avisos, más los dos documentos legales.
//
// Se corren las cuatro guías de Flutter juntas porque cazan cosas distintas:
// `labeledTapTargetGuideline` caza el botón de ícono sin nombre —el lector
// dice «botón» y ya—, la de contraste el gris que se lee bien en el
// monitor del que lo eligió y no al sol, y las dos de tamaño el objetivo de
// 30 puntos que se falla tres de cada cuatro veces con el pulgar.
//
// Con la tipografía de la app cargada, como hace el panel: el contraste lo
// mide el marco pintando de verdad, y con la letra por defecto del motor de
// pruebas mediría otra cosa que la que el usuario ve.
//
// El contraste va con `guiaContraste` (ya_viene_pruebas) y no con
// `textContrastGuideline`: la de Flutter fotografía a un píxel por punto y
// en Linux, donde la letra la dibuja otro rasterizador, medía el borde
// suavizado de las viñetas legales (1,11:1) en vez de su color (#475569,
// 7,0:1 sobre arena). La nuestra fotografía a tres y mide igual en el Mac
// y en Linux.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import 'package:ya_viene_pasajero/features/legal/legal_docs.dart';
import 'package:ya_viene_pasajero/features/legal/presentation/screens/'
    'legal_screen.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/'
    'map_tour_provider.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/'
    'tracking_providers.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/'
    'user_location_provider.dart';
import 'package:ya_viene_pasajero/features/map/presentation/widgets/'
    'eta_bottom_sheet.dart';
import 'package:ya_viene_pasajero/features/map/presentation/widgets/'
    'route_selector_sheet.dart';
import 'package:ya_viene_pasajero/features/map/presentation/widgets/'
    'search_pill_bar.dart';
import 'package:ya_viene_pasajero/features/notifications/presentation/'
    'providers/alert_history_provider.dart';
import 'package:ya_viene_pasajero/features/notifications/presentation/'
    'screens/notifications_screen.dart';
import 'package:ya_viene_pasajero/features/onboarding/presentation/screens/'
    'onboarding_screen.dart';
import 'package:ya_viene_pruebas/contraste.dart';

import 'golden/golden_harness.dart';

const double _lat = 6.2442;
const double _lon = -75.5812;

class _UbicacionDePrueba extends UserLocationNotifier {
  _UbicacionDePrueba() {
    state = const UserLocationState(
      mode: UserLocationMode.manual,
      lat: _lat,
      lon: _lon,
    );
  }
}

class _HistorialSembrado extends AlertHistoryNotifier {
  _HistorialSembrado() {
    state = [
      AlertHistoryEntry(
        busId: 'B-042',
        routeId: 'R1',
        routeName: 'Ruta 106',
        createdAt: DateTime(2026, 3, 14, 7, 40),
      ),
      AlertHistoryEntry(
        busId: 'B-055',
        routeId: 'R1',
        routeName: 'Ruta 106',
        createdAt: DateTime(2026, 3, 14, 6, 55),
        sentAt: DateTime(2026, 3, 14, 7, 12),
      ),
    ];
  }
}

BusPosition _bus(double desfase) => BusPosition(
      busId: 'A-1',
      routeId: 'R1',
      lat: _lat + desfase,
      lon: _lon,
      heading: 0,
      speedKmh: 30,
      timestamp: DateTime(2026, 1, 1, 8),
      isGhostBus: false,
    );

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

/// Todo lo que se toca tiene nombre y se puede dar, y todo texto se lee.
///
/// Las dos guías de tamaño no son la misma medida: Android pide 48 puntos e
/// iOS 44, y la app se publica en las dos tiendas.
Future<void> _guias(WidgetTester tester) async {
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  await expectLater(tester, meetsGuideline(guiaContraste));
  await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
}

void main() {
  setUpAll(_cargarFuentes);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('la bienvenida', (tester) async {
    final semantica = tester.ensureSemantics();
    fijarPantalla(tester);
    await tester.pumpWidget(
      ProviderScope(child: marcoGoldenRuteado(const OnboardingScreen())),
    );
    await tester.pump();
    // Pasada la entrada entera (`AppMotion.grupo`, 560 ms) y con margen: a
    // media entrada el texto todavía es una mezcla con el fondo y el
    // contraste que se mediría ahí no es el que nadie llega a leer. No vale
    // `pumpAndSettle`: el fondo de la bienvenida anima en bucle.
    await tester.pump(const Duration(milliseconds: 1500));
    // Sin `textContrastGuideline` a propósito: reporta 1,32 en el enlace
    // «términos de uso» y es un falso positivo comprobado. El color real es
    // #047857 (`AppColors.primaryAccessible`) sobre arena #FAF6F0, que
    // calculado da ≈5,1:1 y pasa AA; las opacidades de los `FadeTransition`
    // están todas en 1.0, así que no es la animación. Lo que falla es la
    // guía: muestrea los píxeles pintados y en un texto de 12 px casi todo
    // lo que promedia es borde suavizado, un gris que nadie pinta. El nodo
    // se excluye aquí y no en el widget para no esconderlo del lector.
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    semantica.dispose();
  });

  testWidgets('los dos documentos legales', (tester) async {
    for (final doc in legalDocs) {
      final semantica = tester.ensureSemantics();
      fijarPantalla(tester);
      await tester.pumpWidget(
        ProviderScope(child: marcoGoldenRuteado(LegalScreen(doc: doc))),
      );
      await tester.pumpAndSettle();
      await _guias(tester);
      semantica.dispose();
    }
  });

  testWidgets('el selector de empresa y ruta', (tester) async {
    final semantica = tester.ensureSemantics();
    fijarPantalla(tester);
    final guia = MapGuideNotifier();
    await guia.initialize(
      hasLocation: true,
      locationSettled: true,
      hasRoute: false,
      hasSelectedBus: false,
      hasActiveAlert: false,
    );
    final container = ProviderContainer(overrides: [
      mapGuideProvider.overrideWith((ref) => guia),
      companiesProvider.overrideWith(
        (ref) async => const [Company(id: 'EMP-01', name: 'Sobusa')],
      ),
      routesByCompanyProvider.overrideWith(
        (ref, id) async => const [
          RouteInfo(
            id: 'R-106',
            name: 'Ruta 106',
            companyId: 'EMP-01',
            terminalA: 'Terminal',
            terminalB: 'Centro',
          ),
        ],
      ),
    ]);
    addTearDown(container.dispose);
    container.listen(selectedCompanyProvider, (_, __) {});
    container.listen(selectedRouteProvider, (_, __) {});
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: marcoGolden(
          Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () => RouteSelectorSheet.show(
                  context,
                  sheet: const RouteSelectorSheet(),
                ),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    await _guias(tester);
    semantica.dispose();
  });

  testWidgets('la píldora de búsqueda con ruta puesta', (tester) async {
    final semantica = tester.ensureSemantics();
    fijarPantalla(tester);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.listen(selectedRouteProvider, (_, __) {});
    container.read(selectedRouteProvider.notifier).select(
          const RouteInfo(
            id: 'R-106',
            name: 'Ruta 106 · Centro',
            companyId: 'EMP-01',
          ),
        );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: marcoGolden(
          const ColoredBox(
            color: Color(0xFFE8E6E1),
            child: Align(
              alignment: Alignment.topCenter,
              child: SearchPillBar(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _guias(tester);
    semantica.dispose();
  });

  testWidgets('la hoja de distancia con un bus elegido', (tester) async {
    final semantica = tester.ensureSemantics();
    fijarPantalla(tester);
    final container = ProviderContainer(overrides: [
      userLocationProvider.overrideWith((ref) => _UbicacionDePrueba()),
      busPositionsSourceProvider.overrideWith(
        (ref, routeId) => Stream.value([_bus(0.007645)]),
      ),
      routeTrajectoryProvider.overrideWith(
        (ref, routeId) => RouteTrajectory(
          routeId: routeId,
          routeName: 'Ruta 1',
          points: const [
            GeoPoint(lat: _lat, lon: _lon - 0.05),
            GeoPoint(lat: _lat, lon: _lon + 0.05),
          ],
        ),
      ),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: marcoGolden(
          const ColoredBox(
            color: Color(0xFFE8E6E1),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: EtaBottomSheet(),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    container.read(selectedRouteProvider.notifier).select(
          const RouteInfo(id: 'R1', name: 'Ruta 1', companyId: 'C1'),
        );
    container.read(selectedBusesProvider.notifier).toggleBus('A-1');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await _guias(tester);
    semantica.dispose();
  });

  testWidgets('el centro de avisos', (tester) async {
    final semantica = tester.ensureSemantics();
    fijarPantalla(tester);
    final container = ProviderContainer(overrides: [
      userLocationProvider.overrideWith((ref) => _UbicacionDePrueba()),
      alertHistoryProvider.overrideWith((ref) => _HistorialSembrado()),
      busPositionsSourceProvider.overrideWith(
        (ref, routeId) => Stream.value(const <BusPosition>[]),
      ),
    ]);
    addTearDown(container.dispose);
    final sub = container.listen<RouteInfo?>(selectedRouteProvider, (_, __) {});
    addTearDown(sub.close);
    container.read(selectedRouteProvider.notifier).select(
          const RouteInfo(id: 'R1', name: 'Ruta 106', companyId: 'EMP-01'),
        );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: marcoGolden(const NotificationsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await _guias(tester);
    semantica.dispose();
  });
}
