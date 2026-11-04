import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import 'package:ya_viene_pasajero/core/utils/color_empresa.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/map_tour_provider.dart';
import 'package:ya_viene_pasajero/features/map/presentation/widgets/route_selector_sheet.dart';

/// En «Elige ruta» la insignia de cada ruta va en el color de su empresa,
/// el mismo de «Elige empresa» y de la ficha del aviso (dueño, 2026-10-28):
/// Sobusa en su azul, Coolitoral en su verde.
void main() {
  const companies = [
    Company(id: 'EMP-01', name: 'Sobusa'),
    Company(id: 'EMP-03', name: 'Coolitoral'),
  ];

  Future<void> abrirRutasDe(WidgetTester tester, String empresa) async {
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
    final container = ProviderContainer(overrides: [
      mapGuideProvider.overrideWith((ref) => guide),
      companiesProvider.overrideWith((ref) async => companies),
      routesByCompanyProvider.overrideWith(
        (ref, id) async => [
          RouteInfo(id: 'R-$id', name: 'C16 Centro', companyId: id),
        ],
      ),
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
    await tester.tap(find.text('Elegir empresa'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(empresa));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Elegir ruta'));
    await tester.pumpAndSettle();
  }

  /// El fondo de la insignia que lleva el código de la ruta.
  Color? fondoInsignia(WidgetTester tester) {
    final caja = tester.widget<Container>(find
        .ancestor(of: find.text('C16'), matching: find.byType(Container))
        .first);
    return (caja.decoration as BoxDecoration?)?.color;
  }

  Color? letraInsignia(WidgetTester tester) =>
      tester.widget<Text>(find.text('C16')).style?.color;

  for (final empresa in companies) {
    testWidgets('las rutas de ${empresa.name} van en su color', (tester) async {
      await abrirRutasDe(tester, empresa.name);
      expect(fondoInsignia(tester), colorEmpresa(empresa.id));
      expect(letraInsignia(tester), Colors.white);
    });
  }

  /// El fondo de la caja de 44 que lleva el ícono [icono].
  Color? fondoIcono(WidgetTester tester, IconData icono) {
    final caja = tester.widget<Container>(find
        .ancestor(of: find.byIcon(icono), matching: find.byType(Container))
        .first);
    return (caja.decoration as BoxDecoration?)?.color;
  }

  /// Ya elegidas, la empresa y la ruta se visten del color de la empresa
  /// (dueño, 2026-11-03): el filo, la caja del ícono y la palomita de la
  /// fila elegida. El botón y el riel siguen en verde: dicen «listo».
  for (final empresa in companies) {
    testWidgets('con ${empresa.name} elegida, empresa y ruta van en su color',
        (tester) async {
      await abrirRutasDe(tester, empresa.name);
      await tester.tap(find.text('C16'));
      await tester.pumpAndSettle();
      final color = colorEmpresa(empresa.id);
      expect(find.text('Ver buses en vivo'), findsOneWidget);
      expect(fondoIcono(tester, Icons.business_outlined), color);
      // La ruta elegida lleva su código en la caja, como en la lista, y el
      // nombre sin él (dueño, 2026-11-03).
      expect(find.byIcon(Icons.alt_route_outlined), findsNothing);
      expect(fondoInsignia(tester), color);
      expect(letraInsignia(tester), Colors.white);
      expect(find.text('Centro'), findsOneWidget);
      expect(find.text('C16 Centro'), findsNothing);
      expect(tester.widget<Icon>(find.byIcon(Icons.business_outlined)).color,
          Colors.white);

      await tester.tap(find.text(empresa.name));
      await tester.pumpAndSettle();
      expect(
        tester.widget<Icon>(find.byIcon(Icons.check_circle_rounded)).color,
        color,
      );
    });
  }
}
