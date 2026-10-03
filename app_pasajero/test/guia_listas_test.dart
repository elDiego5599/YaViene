import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/map_tour_provider.dart';
import 'package:ya_viene_pasajero/features/map/presentation/widgets/route_selector_sheet.dart';

/// En los pasos de empresa y de ruta la guía ilumina la lista y nada más.
///
/// El hueco era la lista crecida 10 px por los cuatro lados, y por arriba
/// esos 10 px se metían en la cabecera: la flecha de volver quedaba medio
/// iluminada y respondía, así que en mitad de la guía se podía salir de la
/// lista sin elegir nada.
void main() {
  const companies = [Company(id: 'EMP-01', name: 'Sobusa')];
  const routes = [
    RouteInfo(id: 'R-106', name: 'Ruta 106', companyId: 'EMP-01'),
  ];

  Future<void> abrirEnLaLista(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
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
    await guide.moveTo(MapGuideStep.company);
    final container = ProviderContainer(overrides: [
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
                    sheet: RouteSelectorSheet(
                      companyChoiceGuideKey: GlobalKey(),
                      routeChoiceGuideKey: GlobalKey(),
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
    await tester.pumpAndSettle();
    await tester.tap(find.text('Empresa'));
    await tester.pumpAndSettle();
    expect(find.text('Elige empresa'), findsOneWidget);
  }

  testWidgets('la flecha de volver queda fuera del área iluminada',
      (tester) async {
    await abrirEnLaLista(tester);

    expect(find.byKey(const ValueKey('guide_card')), findsOneWidget);
    // Tocar la flecha no sale de la lista: la barrera se lo queda. Se toca
    // por su borde de abajo, que es el que quedaba dentro del hueco.
    final flecha = tester.getRect(find.byTooltip('Volver'));
    await tester.tapAt(flecha.bottomCenter - const Offset(0, 3));
    await tester.pumpAndSettle();
    expect(find.text('Elige empresa'), findsOneWidget);

    // Y la empresa sí se puede elegir.
    await tester.tap(find.text('Sobusa'));
    await tester.pumpAndSettle();
    expect(find.text('Elige empresa'), findsNothing);
  });
}
