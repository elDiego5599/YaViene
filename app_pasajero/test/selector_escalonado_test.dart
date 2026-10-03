import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/map_tour_provider.dart';
import 'package:ya_viene_pasajero/features/map/presentation/widgets/route_selector_sheet.dart';

/// Las filas de «Elige empresa» y «Elige ruta» entran escalonadas: la
/// primera llega y las siguientes detrás, como una lista de iOS que se
/// asienta, en vez de pintarse de golpe dentro del empuje lateral. Un solo
/// reloj para todas (`ScreenEntrance`), y el escalón se topa: la décima fila
/// no hace esperar.
void main() {
  const companies = [
    Company(id: 'EMP-01', name: 'Sobusa'),
    Company(id: 'EMP-02', name: 'Coolitoral'),
    Company(id: 'EMP-03', name: 'Transmecar'),
  ];

  Future<void> abrirEmpresas(WidgetTester tester,
      {bool reducido = false}) async {
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
    final container = ProviderContainer(overrides: [
      mapGuideProvider.overrideWith((ref) => guide),
      companiesProvider.overrideWith((ref) async => companies),
      routesByCompanyProvider.overrideWith((ref, id) async => const []),
    ]);
    addTearDown(container.dispose);
    container.listen(selectedCompanyProvider, (_, __) {});
    container.listen(selectedRouteProvider, (_, __) {});

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MediaQuery(
          data: MediaQueryData(
            size: const Size(390, 844),
            disableAnimations: reducido,
          ),
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
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Elegir empresa'));
    await tester.pump();
  }

  /// La opacidad propia de la fila: el `FadeTransition` más cercano. Por
  /// encima está el del cambio de vista, que es el mismo para todas.
  double opacidad(WidgetTester tester, String nombre) => tester
      .widget<FadeTransition>(find
          .ancestor(
              of: find.text(nombre), matching: find.byType(FadeTransition))
          .first)
      .opacity
      .value;

  testWidgets('las filas entran una detrás de otra', (tester) async {
    await abrirEmpresas(tester);
    await tester.pump(const Duration(milliseconds: 120));

    final primera = opacidad(tester, 'Sobusa');
    final tercera = opacidad(tester, 'Transmecar');
    expect(primera, greaterThan(tercera));

    await tester.pumpAndSettle();
    for (final empresa in companies) {
      expect(opacidad(tester, empresa.name), 1.0, reason: empresa.name);
    }
  });

  testWidgets('con movimiento reducido las filas no se desplazan',
      (tester) async {
    await abrirEmpresas(tester, reducido: true);
    await tester.pump(const Duration(milliseconds: 60));
    final slide = tester.widget<SlideTransition>(find
        .ancestor(
            of: find.text('Transmecar'), matching: find.byType(SlideTransition))
        .first);
    expect(slide.position.value, Offset.zero);
    await tester.pumpAndSettle();
  });
}
