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

  testWidgets('la guía acompaña empresa, ruta y buses en vivo', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final guide = MapGuideNotifier();
    await guide.initialize(
      hasLocation: true,
      locationSettled: true,
      hasRoute: false,
      hasSelectedBus: false,
      hasActiveAlert: false,
    );
    await guide.complete(MapGuideStep.search);

    final container = ProviderContainer(overrides: [
      mapGuideProvider.overrideWith((ref) => guide),
      companiesProvider.overrideWith((ref) async => const [company]),
      routesByCompanyProvider
          .overrideWith((ref, companyId) async => const [route]),
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

    await tester.tap(find.text('Sobusa').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(guide.state.step, MapGuideStep.route);

    await tester.tap(find.text('Selecciona una ruta'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('B18 Tcherassi'), findsOneWidget);

    await tester.tap(find.text('B18 Tcherassi').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(guide.state.step, MapGuideStep.launchBuses);
    expect(find.text('Ver buses en vivo'), findsOneWidget);
  });
}
