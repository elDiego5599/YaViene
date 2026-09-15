import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/map_tour_provider.dart';
import 'package:ya_viene_pasajero/features/map/presentation/widgets/route_selector_sheet.dart';

void main() {
  const company = Company(id: 'EMP-01', name: 'Sobusa');
  const route = RouteInfo(
    id: 'R-101',
    name: 'B18 Tcherassi',
    companyId: 'EMP-01',
  );
  final companies = [
    company,
    for (var i = 2; i <= 8; i++) Company(id: 'EMP-0$i', name: 'Empresa $i'),
  ];
  final routes = [
    route,
    for (var i = 2; i <= 8; i++)
      RouteInfo(
        id: 'R-10$i',
        name: 'Ruta $i',
        companyId: 'EMP-08',
      ),
  ];

  late MapGuideNotifier guide;
  late ProviderContainer container;

  final companyGuideKey = GlobalKey();
  final companyChoiceGuideKey = GlobalKey();
  final routeGuideKey = GlobalKey();
  final routeChoiceGuideKey = GlobalKey();
  final launchBusesGuideKey = GlobalKey();

  Future<void> pumpSheet(WidgetTester tester) async {
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
                    sheet: RouteSelectorSheet(
                      companyGuideKey: companyGuideKey,
                      companyChoiceGuideKey: companyChoiceGuideKey,
                      routeGuideKey: routeGuideKey,
                      routeChoiceGuideKey: routeChoiceGuideKey,
                      launchBusesGuideKey: launchBusesGuideKey,
                    ),
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
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> setup(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    guide = MapGuideNotifier();
    await guide.initialize(
      hasLocation: true,
      locationSettled: true,
      hasRoute: false,
      hasSelectedBus: false,
      hasActiveAlert: false,
    );
    await guide.complete(MapGuideStep.search);

    container = ProviderContainer(overrides: [
      mapGuideProvider.overrideWith((ref) => guide),
      companiesProvider.overrideWith((ref) async => companies),
      routesByCompanyProvider.overrideWith((ref, companyId) async => routes),
    ]);
    addTearDown(container.dispose);
    container.listen(selectedCompanyProvider, (_, __) {});
    container.listen(selectedRouteProvider, (_, __) {});
  }

  testWidgets('la guía acompaña empresa, ruta y buses en vivo', (tester) async {
    await setup(tester);
    await pumpSheet(tester);

    expect(guide.state.step, MapGuideStep.company);
    expect(find.text('Elige una empresa'), findsOneWidget);

    await tester.tap(find.text('Empresa'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Sobusa'), findsOneWidget);

    await tester.drag(find.byType(ListView).last, const Offset(0, -500));
    await tester.pump();
    expect(find.text('Empresa 8'), findsOneWidget);
    await tester.tap(find.text('Empresa 8'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(guide.state.step, MapGuideStep.route);

    await tester.tap(find.text('Ruta'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    // El código va en la insignia y el nombre en el título: la fila dice
    // «B18» y «Tcherassi» por separado, que es como se lee en el parabrisas.
    expect(find.text('B18'), findsOneWidget);
    expect(find.text('Tcherassi'), findsOneWidget);

    await tester.drag(find.byType(ListView).last, const Offset(0, -500));
    await tester.pump();
    expect(find.text('Ruta 8'), findsOneWidget);
    await tester.tap(find.text('Ruta 8'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(guide.state.step, MapGuideStep.launchBuses);
    expect(find.text('Ver buses en vivo'), findsOneWidget);
  });

  testWidgets('Saltar guía detiene la guía pero deja el selector abierto',
      (tester) async {
    await setup(tester);
    await pumpSheet(tester);
    expect(guide.state.step, MapGuideStep.company);
    expect(find.byKey(const ValueKey('guide_skip')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('guide_skip')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(guide.state.skipped, isTrue);
    expect(guide.state.step, isNull);
    // El usuario se queda donde estaba: el selector sigue visible en su vista
    // principal, sin el overlay de la guía.
    expect(find.byKey(const ValueKey('guide_skip')), findsNothing);
    expect(find.text('Empresa'), findsOneWidget);
    expect(find.text('Elige tu ruta'), findsOneWidget);
  });

  testWidgets('al lanzar buses la guía cierra el selector de forma natural',
      (tester) async {
    await setup(tester);
    await pumpSheet(tester);

    await tester.tap(find.text('Empresa'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.drag(find.byType(ListView).last, const Offset(0, -500));
    await tester.pump();
    await tester.tap(find.text('Empresa 8'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('Ruta'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.drag(find.byType(ListView).last, const Offset(0, -500));
    await tester.pump();
    await tester.tap(find.text('Ruta 8'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(guide.state.step, MapGuideStep.launchBuses);

    // Se simula el éxito del lanzamiento: la guía pasa a "buses" (paso de
    // mapa) y el selector se cierra solo.
    await guide.complete(MapGuideStep.launchBuses);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    // La salida del selector dura `AppMotion.entrada` y arranca un
    // fotograma tarde, porque el cierre lo pide un post-frame.
    await tester.pump(const Duration(milliseconds: 500));

    expect(guide.state.step, MapGuideStep.buses);
    expect(find.text('Elige tu ruta'), findsNothing);
    expect(find.text('abrir'), findsOneWidget);
  });
}
