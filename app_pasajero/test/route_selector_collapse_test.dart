import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/map_tour_provider.dart';
import 'package:ya_viene_pasajero/features/map/presentation/widgets/route_selector_sheet.dart';

/// La tarjeta de "Elige tu ruta" se pliega para mirar el mapa sin cerrarla.
///
/// Solo la principal: dentro de las listas de empresa y de ruta el gesto se
/// apaga, porque ahí el usuario está en mitad de una elección y plegar le
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

  double altoTarjeta(WidgetTester tester) {
    final tarjeta = find.byWidgetPredicate(
      (w) =>
          w is Material &&
          w.shape ==
              const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                side: BorderSide(color: AppColors.hairline),
              ),
    );
    expect(tarjeta, findsOneWidget);
    return tester.getSize(tarjeta).height;
  }

  Future<void> abrir(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final guide = MapGuideNotifier();
    await guide.initialize(
      userId: 'plegar-user',
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

  testWidgets('la tarjeta principal se pliega y se vuelve a abrir',
      (tester) async {
    await abrir(tester);
    final abierta = altoTarjeta(tester);

    await tester.tap(asa());
    await tester.pumpAndSettle();
    expect(find.text('Elige tu ruta'), findsNothing);
    expect(altoTarjeta(tester), lessThan(abierta));
    expect(asa(), findsOneWidget, reason: 'el asa es lo que queda para abrir');

    await tester.tap(asa());
    await tester.pumpAndSettle();
    expect(find.text('Elige tu ruta'), findsOneWidget);
    expect(altoTarjeta(tester), abierta);
  });

  testWidgets('eligiendo empresa o ruta el asa ya no pliega', (tester) async {
    await abrir(tester);

    await tester.tap(find.text('Empresa'));
    await tester.pumpAndSettle();
    final alto = altoTarjeta(tester);

    await tester.tap(asa());
    await tester.pumpAndSettle();
    expect(find.text('Elige empresa'), findsOneWidget);
    expect(altoTarjeta(tester), alto);

    await tester.tap(find.text('Sobusa'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ruta'));
    await tester.pumpAndSettle();
    expect(find.text('Elige ruta'), findsOneWidget);

    await tester.tap(asa());
    await tester.pumpAndSettle();
    expect(find.text('Elige ruta'), findsOneWidget);
    expect(altoTarjeta(tester), alto);
  });
}
