import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import 'package:ya_viene_pasajero/core/widgets/sheet_top_border.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/map_tour_provider.dart';
import 'package:ya_viene_pasajero/features/map/presentation/widgets/route_selector_sheet.dart';

/// La tarjeta del selector no cambia de tamaño entre sus tres vistas.
///
/// Las listas de empresa y de ruta se dibujan como `SizedBox` con la altura
/// medida de la vista principal. Esa medida salía del `Column` interior, o
/// sea sin el relleno de 16 arriba y 24 abajo que la vista principal tiene
/// alrededor: la tarjeta se encogía 40 px al entrar a elegir y volvía a
/// crecer al salir. Entre las tres vistas solo debe cambiar el contenido.
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

  /// Alto real de la hoja: el `Material` con el filo redondeado de arriba.
  double altoTarjeta(WidgetTester tester) {
    final tarjeta = find.byWidgetPredicate(
      (w) =>
          w is Material &&
          w.shape ==
              const SheetTopBorder(
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

  testWidgets('la tarjeta mide igual en las tres vistas', (tester) async {
    await abrir(tester);

    final principal = altoTarjeta(tester);
    expect(principal, greaterThan(0));

    await tester.tap(find.text('Empresa'));
    await tester.pumpAndSettle();
    expect(find.text('Elige empresa'), findsOneWidget);
    expect(altoTarjeta(tester), principal);

    await tester.tap(find.text('Sobusa'));
    await tester.pumpAndSettle();
    expect(altoTarjeta(tester), principal);

    await tester.tap(find.text('Ruta'));
    await tester.pumpAndSettle();
    expect(find.text('Elige ruta'), findsOneWidget);
    expect(altoTarjeta(tester), principal);
  });

  // Con una sola empresa la hoja se queda en su alto (arriba) y la fila de
  // empresa es la misma tarjeta que se acaba de tocar: si midiera menos,
  // flotaría arriba como una etiqueta en una hoja vacía.
  testWidgets('la fila de empresa y la de ruta miden como la tarjeta del paso',
      (tester) async {
    await abrir(tester);

    Size tarjetaDe(String texto, Type tipo) => tester.getSize(
        find.ancestor(of: find.text(texto), matching: find.byType(tipo)).first);

    final paso = tarjetaDe('Empresa', AnimatedContainer);

    await tester.tap(find.text('Empresa'));
    await tester.pumpAndSettle();
    expect(tarjetaDe('Sobusa', InkWell).height, paso.height);

    await tester.tap(find.text('Sobusa'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ruta'));
    await tester.pumpAndSettle();
    expect(tarjetaDe('Ruta 106', InkWell).height, paso.height);
  });
}
