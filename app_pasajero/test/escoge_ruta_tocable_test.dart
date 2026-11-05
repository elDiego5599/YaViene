import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/map_tour_provider.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/map_view_state.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/tracking_providers.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/user_location_provider.dart';
import 'package:ya_viene_pasajero/features/map/presentation/widgets/eta_bottom_sheet.dart';
import 'package:ya_viene_pasajero/features/map/presentation/widgets/route_selector_sheet.dart';
import 'package:ya_viene_pasajero/features/map/presentation/widgets/search_pill_bar.dart';

/// «Escoge empresa y ruta» abre el selector (dueño, 2026-09-28: lo probó con
/// varias personas y todas tocaban ahí, en el ícono de la hoja, y no pasaba
/// nada). La hoja pide el selector; lo abre la píldora, que es la dueña del
/// selector y de sus guías.
class _TestUserLocation extends UserLocationNotifier {
  void set(UserLocationState state) => this.state = state;
}

void main() {
  late ProviderContainer container;

  Future<void> montar(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final guide = MapGuideNotifier();
    await guide.initialize(
      hasLocation: true,
      locationSettled: true,
      hasRoute: false,
      hasSelectedBus: false,
      hasActiveAlert: false,
    );
    await guide.empezar();
    container = ProviderContainer(overrides: [
      mapGuideProvider.overrideWith((ref) => guide),
      userLocationProvider.overrideWith((ref) => _TestUserLocation()),
      busPositionsSourceProvider.overrideWith(
        (ref, routeId) => Stream.value(const <BusPosition>[]),
      ),
      companiesProvider.overrideWith(
        (ref) async => const [Company(id: 'EMP-01', name: 'Sobusa')],
      ),
      routesByCompanyProvider.overrideWith(
        (ref, id) async => const <RouteInfo>[],
      ),
    ]);
    addTearDown(container.dispose);
    container.listen(selectedRouteProvider, (_, __) {});
    (container.read(userLocationProvider.notifier) as _TestUserLocation).set(
      const UserLocationState(
        mode: UserLocationMode.manual,
        lat: 6.2442,
        lon: -75.5812,
      ),
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                Align(
                  alignment: Alignment.topCenter,
                  child: SearchPillBar(),
                ),
                EtaBottomSheet(),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('tocar el ícono de «Escoge empresa y ruta» abre el selector', (
    tester,
  ) async {
    await montar(tester);
    expect(find.byType(RouteSelectorSheet), findsNothing);

    await tester.tap(find.byKey(const ValueKey('escoge-ruta-icono')));
    await tester.pumpAndSettle();

    expect(find.byType(RouteSelectorSheet), findsOneWidget);
    expect(container.read(routeSelectorOpenProvider), isTrue);
  });

  // El ícono gris se cambió por el selector en miniatura (dueño, 2026-11-05:
  // junto al pin de «Toca el mapa» se veía horrible). El medallón sigue
  // blanco con su sombra, como los demás estados; el verde de un ícono no
  // gustó (2026-09-29), así que el dibujo va en el color de una empresa.
  testWidgets('el medallón lleva el selector en miniatura, sin ícono', (
    tester,
  ) async {
    await montar(tester);

    final medallon = find.byKey(const ValueKey('escoge-ruta-icono'));
    final caja =
        tester.widget<Container>(medallon).decoration! as BoxDecoration;
    expect(caja.color, AppColors.surface);
    // Blanco sobre la hoja blanca: sin sombra el medallón no se ve.
    expect(caja.boxShadow, isNotEmpty);
    expect(
      find.descendant(
          of: medallon,
          matching: find.byKey(const ValueKey('sena-elegir-ruta'))),
      findsOneWidget,
    );
    expect(find.descendant(of: medallon, matching: find.byType(Icon)),
        findsNothing);
  });

  testWidgets('el título y la frase también lo abren', (tester) async {
    await montar(tester);

    await tester.tap(find.text('Escoge empresa y ruta'));
    await tester.pumpAndSettle();

    expect(find.byType(RouteSelectorSheet), findsOneWidget);
  });

  testWidgets('se anuncia como botón con su nombre', (tester) async {
    final semantica = tester.ensureSemantics();
    await montar(tester);

    expect(
      tester.getSemantics(find.byKey(const ValueKey('empty-no-route-boton'))),
      isSemantics(
        isButton: true,
        hasTapAction: true,
        label: 'Escoge empresa y ruta\n'
            'Toca aquí para elegir la empresa y su ruta',
      ),
    );
    semantica.dispose();
  });
}
