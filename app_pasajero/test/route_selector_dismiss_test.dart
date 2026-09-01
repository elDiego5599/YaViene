import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import 'package:ya_viene_pasajero/core/widgets/sheet_top_border.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/map_tour_provider.dart';
import 'package:ya_viene_pasajero/features/map/presentation/widgets/route_selector_sheet.dart';

/// La tarjeta de "Elige tu ruta" se descarta arrastrándola hacia abajo.
///
/// No se pliega: plegada dejaba un asa muerta encima del mapa, tapando la
/// hoja de distancia que se apoya en el mismo borde. Bajar una hoja es pedir
/// que se vaya, así que se va del todo y el diálogo se cierra con ella.
///
/// Solo la principal: dentro de las listas de empresa y de ruta el gesto se
/// apaga, porque ahí el usuario está en mitad de una elección y cerrar le
/// quitaría de delante justo lo que fue a buscar.
void main() {
  const companies = [Company(id: 'EMP-01', name: 'Sobusa')];
  const routes = [
    RouteInfo(
      id: 'R-106',
      name: 'Ruta 106',
      companyId: 'EMP-01',
      terminalA: 'Terminal',
      terminalB: 'Centro',
    ),
  ];

  late ProviderContainer container;

  Finder asa() => find.byKey(const ValueKey('selector-handle'));

  Finder tarjeta() => find.byWidgetPredicate(
        (w) =>
            w is Material &&
            w.shape ==
                const SheetTopBorder(
                  side: BorderSide(color: AppColors.hairline),
                ),
      );

  Future<void> abrir(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final guide = MapGuideNotifier();
    await guide.initialize(
      userId: 'descartar-user',
      isNewUser: false,
      hasLocation: true,
      locationSettled: true,
      hasRoute: false,
      hasSelectedBus: false,
      hasActiveAlert: false,
    );
    container = ProviderContainer(overrides: [
      mapGuideProvider.overrideWith((ref) => guide),
      companiesProvider.overrideWith((ref) async => companies),
      routesByCompanyProvider.overrideWith((ref, id) async => routes),
    ]);
    addTearDown(container.dispose);
    container.listen(selectedCompanyProvider, (_, __) {});
    container.listen(selectedRouteProvider, (_, __) {});

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
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
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
  }

  /// Dónde está el borde de arriba de la tarjeta: al irse, baja.
  double bordeTarjeta(WidgetTester tester) => tester.getTopLeft(tarjeta()).dy;

  /// Lo oscuro que está el mapa detrás de la tarjeta.
  double velo(WidgetTester tester) => tester
      .widget<ColoredBox>(find.byKey(const ValueKey('selector-velo')))
      .color
      .a;

  testWidgets('el asa cierra el selector entero, no lo pliega', (tester) async {
    await abrir(tester);
    expect(velo(tester), greaterThan(0));

    await tester.tap(asa());
    await tester.pumpAndSettle();

    expect(find.text('Elige tu ruta'), findsNothing);
    expect(asa(), findsNothing, reason: 'no queda un asa suelta en el mapa');
    expect(find.byKey(const ValueKey('selector-velo')), findsNothing);
    expect(find.text('abrir'), findsOneWidget, reason: 'vuelve el mapa');
  });

  testWidgets('la tarjeta baja pegada al dedo y vuelve sola al soltar',
      (tester) async {
    await abrir(tester);
    final arriba = bordeTarjeta(tester);
    final alto = tester.getSize(tarjeta()).height;

    final gesto = await tester.startGesture(tester.getCenter(asa()));
    for (var i = 0; i < 3; i++) {
      await gesto.moveBy(Offset(0, alto / 9));
      await tester.pump(const Duration(milliseconds: 16));
    }
    final aMedias = bordeTarjeta(tester);
    expect(aMedias, greaterThan(arriba), reason: 'baja mientras el dedo baja');
    expect(velo(tester), lessThan(0.40), reason: 'el velo se aclara con ella');

    // Se suelta quieta y a un tercio del camino: vuelve a su sitio.
    await tester.pump(const Duration(milliseconds: 200));
    await gesto.up();
    await tester.pumpAndSettle();
    expect(find.text('Elige tu ruta'), findsOneWidget);
    expect(bordeTarjeta(tester), arriba);
    expect(velo(tester), greaterThan(0));
  });

  testWidgets('soltar con impulso hacia abajo termina de sacarla',
      (tester) async {
    await abrir(tester);
    final alto = tester.getSize(tarjeta()).height;

    await tester.fling(asa(), Offset(0, alto / 3), 1200);
    await tester.pumpAndSettle();

    expect(find.text('Elige tu ruta'), findsNothing,
        reason: 'el impulso manda sobre lo poco que se anduvo');
    expect(find.text('abrir'), findsOneWidget);
  });

  testWidgets('subiendo el dedo la tarjeta se queda', (tester) async {
    await abrir(tester);
    final arriba = bordeTarjeta(tester);
    final alto = tester.getSize(tarjeta()).height;

    await tester.fling(asa(), Offset(0, -alto / 6), 1200);
    await tester.pumpAndSettle();

    expect(find.text('Elige tu ruta'), findsOneWidget);
    expect(bordeTarjeta(tester), arriba, reason: 'no sube más de la cuenta');
  });

  testWidgets('eligiendo empresa o ruta el asa ya no cierra', (tester) async {
    await abrir(tester);

    await tester.tap(find.text('Empresa'));
    await tester.pumpAndSettle();

    await tester.tap(asa());
    await tester.pumpAndSettle();
    expect(find.text('Elige empresa'), findsOneWidget);
    expect(velo(tester), greaterThan(0), reason: 'el velo se queda');

    await tester.tap(find.text('Sobusa'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ruta'));
    await tester.pumpAndSettle();
    expect(find.text('Elige ruta'), findsOneWidget);

    await tester.tap(asa());
    await tester.pumpAndSettle();
    expect(find.text('Elige ruta'), findsOneWidget);
  });
}
