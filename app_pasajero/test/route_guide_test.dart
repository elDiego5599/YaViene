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

  testWidgets('la guía acompaña empresa, ruta y buses en vivo', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final guide = MapGuideNotifier();
    await guide.initialize(
      userId: 'route-user',
      isNewUser: true,
      hasLocation: true,
      locationSettled: true,
      hasRoute: false,
      hasSelectedBus: false,
      hasActiveAlert: false,
    );
    await guide.complete(MapGuideStep.search);

    final container = ProviderContainer(overrides: [
      mapGuideProvider.overrideWith((ref) => guide),
      companiesProvider.overrideWith((ref) async => companies),
      routesByCompanyProvider.overrideWith((ref, companyId) async => routes),
    ]);
    addTearDown(container.dispose);

    final companyGuideKey = GlobalKey();
    final companyChoiceGuideKey = GlobalKey();
    final routeGuideKey = GlobalKey();
    final routeChoiceGuideKey = GlobalKey();
    final launchBusesGuideKey = GlobalKey();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: RouteSelectorSheet(
              companyGuideKey: companyGuideKey,
              companyChoiceGuideKey: companyChoiceGuideKey,
              routeGuideKey: routeGuideKey,
              routeChoiceGuideKey: routeChoiceGuideKey,
              launchBusesGuideKey: launchBusesGuideKey,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(guide.state.step, MapGuideStep.company);
    expect(find.text('Elige una empresa'), findsOneWidget);

    await tester.tap(find.text('Selecciona una empresa'));
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

    await tester.tap(find.text('Selecciona una ruta'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('B18 Tcherassi'), findsOneWidget);

    await tester.drag(find.byType(ListView).last, const Offset(0, -500));
    await tester.pump();
    expect(find.text('Ruta 8'), findsOneWidget);
    await tester.tap(find.text('Ruta 8'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(guide.state.step, MapGuideStep.launchBuses);
    expect(find.text('Ver buses en vivo'), findsOneWidget);
  });
}
