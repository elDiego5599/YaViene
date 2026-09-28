import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import 'package:ya_viene_pasajero/core/widgets/sheet_top_border.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/map_tour_provider.dart';
import 'package:ya_viene_pasajero/features/map/presentation/widgets/route_selector_sheet.dart';

/// La tarjeta del selector no crece entre sus tres vistas, y no se queda
/// vacía.
///
/// Las listas de empresa y de ruta se dibujan con la altura medida de la
/// vista principal como tope. Esa medida salía del `Column` interior, o sea
/// sin el relleno de 16 arriba y 24 abajo que la vista principal tiene
/// alrededor: la tarjeta se encogía 40 px al entrar a elegir y volvía a
/// crecer al salir. Con una lista larga, entre las tres vistas solo cambia
/// el contenido.
///
/// Pero ese alto fijo era también el piso: con una sola empresa —la flota de
/// hoy— la hoja seguía midiendo lo de la vista principal y debajo de la
/// única fila quedaban unos 200 px de arena vacía. Ahora una lista corta se
/// queda con su alto y la hoja baja hasta ella, como la hoja de pago de iOS
/// entre un paso y otro.
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

  Future<void> abrir(WidgetTester tester, List<Company> empresas) async {
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
      companiesProvider.overrideWith((ref) async => empresas),
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

  /// Lo que queda de hoja debajo de la última fila de la lista.
  double sobraDebajo(WidgetTester tester) {
    final tarjeta = find.byWidgetPredicate(
      (w) =>
          w is Material &&
          w.shape ==
              const SheetTopBorder(
                side: BorderSide(color: AppColors.hairline),
              ),
    );
    return tester.getRect(tarjeta).bottom -
        tester
            .getRect(find
                .descendant(
                  of: find.byType(ListView),
                  matching: find.byType(InkWell),
                )
                .last)
            .bottom;
  }

  testWidgets('con una sola empresa la hoja no se queda vacía', (tester) async {
    await abrir(tester, companies);

    final principal = altoTarjeta(tester);
    expect(principal, greaterThan(0));

    await tester.tap(find.text('Empresa'));
    await tester.pumpAndSettle();
    expect(find.text('Elige empresa'), findsOneWidget);
    expect(altoTarjeta(tester), lessThan(principal));
    // Debajo de la fila, su separación con la siguiente (8), el fundido de
    // la lista (16) y el margen de la hoja (24). Nada más.
    expect(sobraDebajo(tester), lessThanOrEqualTo(48 + 1));

    await tester.tap(find.text('Sobusa'));
    await tester.pumpAndSettle();
    expect(altoTarjeta(tester), principal);

    await tester.tap(find.text('Ruta'));
    await tester.pumpAndSettle();
    expect(find.text('Elige ruta'), findsOneWidget);
    expect(altoTarjeta(tester), lessThan(principal));
    expect(sobraDebajo(tester), lessThanOrEqualTo(48 + 1));

    await tester.tap(find.byIcon(Icons.arrow_back_outlined));
    await tester.pumpAndSettle();
    expect(altoTarjeta(tester), principal);
  });

  testWidgets('con muchas empresas la lista no pasa del alto principal',
      (tester) async {
    await abrir(tester, [
      for (var i = 0; i < 12; i++) Company(id: 'EMP-$i', name: 'Empresa $i'),
    ]);

    final principal = altoTarjeta(tester);
    await tester.tap(find.text('Empresa'));
    await tester.pumpAndSettle();
    expect(find.text('Elige empresa'), findsOneWidget);
    expect(altoTarjeta(tester), principal);
  });
}
