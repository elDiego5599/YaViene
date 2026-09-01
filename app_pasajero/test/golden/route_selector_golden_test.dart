import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/'
    'map_tour_provider.dart';
import 'package:ya_viene_pasajero/features/map/presentation/widgets/'
    'route_selector_sheet.dart';

import 'golden_harness.dart';

/// El selector de empresa y ruta en sus tres vistas.
///
/// Doce estilos escritos a mano, la mayor concentración de la app. Va como
/// diálogo a pantalla completa, así que la foto sale con su velo y todo.
const _empresas = [
  Company(id: 'EMP-01', name: 'Sobusa'),
  Company(id: 'EMP-02', name: 'Coolitoral'),
];

const _rutas = [
  RouteInfo(
    id: 'R-106',
    name: 'Ruta 106',
    companyId: 'EMP-01',
    terminalA: 'Terminal',
    terminalB: 'Centro',
  ),
  RouteInfo(
    id: 'R-112',
    name: 'Ruta 112',
    companyId: 'EMP-01',
    terminalA: 'Mallorquín',
    terminalB: 'La Playa',
  ),
];

void main() {
  Future<ProviderContainer> abrir(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    // La guía se inicializa ya vista: si arrancara, taparía el selector con
    // su velo y la foto sería de la guía, no del selector.
    final guia = MapGuideNotifier();
    await guia.initialize(
      userId: 'golden-user',
      isNewUser: false,
      hasLocation: true,
      locationSettled: true,
      hasRoute: false,
      hasSelectedBus: false,
      hasActiveAlert: false,
    );
    final container = ProviderContainer(overrides: [
      mapGuideProvider.overrideWith((ref) => guia),
      companiesProvider.overrideWith((ref) async => _empresas),
      routesByCompanyProvider.overrideWith((ref, id) async => _rutas),
    ]);
    addTearDown(container.dispose);
    container.listen(selectedCompanyProvider, (_, __) {});
    container.listen(selectedRouteProvider, (_, __) {});

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: marcoGolden(
          ColoredBox(
            color: const Color(0xFFE8E6E1),
            child: Builder(
              builder: (context) => Center(
                child: TextButton(
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
    return container;
  }

  testWidgets('selector · vista principal', (tester) async {
    fijarPantalla(tester);
    await abrir(tester);
    await coincideConOro(tester, 'selector_principal');
  });

  testWidgets('selector · lista de empresas', (tester) async {
    fijarPantalla(tester);
    await abrir(tester);
    await tester.tap(find.text('Empresa'));
    await tester.pumpAndSettle();
    await coincideConOro(tester, 'selector_empresas');
  });

  testWidgets('selector · lista de rutas', (tester) async {
    fijarPantalla(tester);
    await abrir(tester);
    await tester.tap(find.text('Empresa'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sobusa'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ruta'));
    await tester.pumpAndSettle();
    await coincideConOro(tester, 'selector_rutas');
  });

  testWidgets('selector · con empresa y ruta ya elegidas', (tester) async {
    fijarPantalla(tester);
    final container = await abrir(tester);
    container.read(selectedCompanyProvider.notifier).select(_empresas.first);
    container.read(selectedRouteProvider.notifier).select(_rutas.first);
    await tester.pumpAndSettle();
    await coincideConOro(tester, 'selector_completo');
  });
}
