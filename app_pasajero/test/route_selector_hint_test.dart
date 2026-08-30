import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/map_tour_provider.dart';
import 'package:ya_viene_pasajero/features/map/presentation/widgets/route_selector_sheet.dart';

/// El aviso de "falta la empresa" tiene que verse.
///
/// Antes era un SnackBar: la hoja se abre con `showGeneralDialog`, o sea en
/// una ruta por encima de la del mapa, y `ScaffoldMessenger.of(context)`
/// resolvía al Scaffold del mapa. El SnackBar existía y era invisible,
/// tapado por el velo del diálogo y por la propia tarjeta.
void main() {
  const companies = [Company(id: 'EMP-01', name: 'Sobusa')];

  late ProviderContainer container;

  Future<void> setup(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final guide = MapGuideNotifier();
    await guide.initialize(
      userId: 'hint-user',
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
    ]);
    addTearDown(container.dispose);
    container.listen(selectedCompanyProvider, (_, __) {});
    container.listen(selectedRouteProvider, (_, __) {});
  }

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

  testWidgets('sin empresa, el aviso sale pegado al tile de ruta',
      (tester) async {
    await setup(tester);
    await pumpSheet(tester);

    expect(find.text('Elige primero la empresa'), findsNothing);

    await tester.tap(find.text('Ruta'));
    await tester.pump();

    // Está en el árbol del diálogo, no en un SnackBar del Scaffold de abajo.
    expect(find.text('Elige primero la empresa'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    // Y no navegó a la lista de rutas.
    expect(find.text('Ruta'), findsOneWidget);

    // Se retira solo.
    await tester.pump(const Duration(milliseconds: 2700));
    await tester.pumpAndSettle();
    expect(find.text('Elige primero la empresa'), findsNothing);
  });

  testWidgets('elegir empresa retira el aviso al momento', (tester) async {
    await setup(tester);
    await pumpSheet(tester);

    await tester.tap(find.text('Ruta'));
    await tester.pump();
    expect(find.text('Elige primero la empresa'), findsOneWidget);

    await tester.tap(find.text('Empresa'));
    await tester.pumpAndSettle();
    expect(find.text('Elige primero la empresa'), findsNothing);
  });
}
