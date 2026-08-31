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

  /// Cuánto contenido queda a la vista: 0 es plegada del todo.
  double altoPliegue(WidgetTester tester) =>
      tester.getSize(find.byKey(const ValueKey('selector-pliegue'))).height;

  /// Lo oscuro que está el mapa detrás de la tarjeta.
  double velo(WidgetTester tester) => tester
      .widget<ColoredBox>(find.byKey(const ValueKey('selector-velo')))
      .color
      .a;

  testWidgets('la tarjeta principal se pliega y se vuelve a abrir',
      (tester) async {
    await abrir(tester);
    final abierta = altoTarjeta(tester);
    expect(velo(tester), greaterThan(0));

    await tester.tap(asa());
    await tester.pumpAndSettle();
    expect(altoPliegue(tester), 0);
    expect(altoTarjeta(tester), lessThan(abierta));
    expect(asa(), findsOneWidget, reason: 'el asa es lo que queda para abrir');
    expect(velo(tester), 0,
        reason: 'plegarla es pedir ver el mapa: el velo se va con ella');

    await tester.tap(asa());
    await tester.pumpAndSettle();
    expect(find.text('Elige tu ruta'), findsOneWidget);
    expect(altoTarjeta(tester), abierta);
    expect(velo(tester), greaterThan(0));
  });

  testWidgets('la tarjeta baja pegada al dedo y se abre sola al soltar',
      (tester) async {
    await abrir(tester);
    final abierta = altoPliegue(tester);

    final gesto = await tester.startGesture(tester.getCenter(asa()));
    for (var i = 0; i < 3; i++) {
      await gesto.moveBy(Offset(0, abierta / 9));
      await tester.pump(const Duration(milliseconds: 16));
    }
    final aMedias = altoPliegue(tester);
    expect(aMedias, lessThan(abierta), reason: 'baja mientras el dedo baja');
    expect(aMedias, greaterThan(0), reason: 'no se cierra de golpe');
    expect(velo(tester), lessThan(0.40), reason: 'el velo se aclara con ella');

    // Se suelta quieto y a un tercio del camino: vuelve arriba.
    await tester.pump(const Duration(milliseconds: 200));
    await gesto.up();
    await tester.pumpAndSettle();
    expect(altoPliegue(tester), abierta);
  });

  testWidgets('soltar con impulso hacia abajo termina de plegarla',
      (tester) async {
    await abrir(tester);
    final abierta = altoPliegue(tester);

    await tester.fling(asa(), Offset(0, abierta / 3), 1200);
    await tester.pumpAndSettle();
    expect(altoPliegue(tester), 0, reason: 'el impulso manda sobre lo andado');
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
    expect(velo(tester), greaterThan(0), reason: 'el velo se queda');

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
