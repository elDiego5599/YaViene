import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/tracking_providers.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/user_location_provider.dart';
import 'package:ya_viene_pasajero/features/map/presentation/widgets/eta_bottom_sheet.dart';

class _TestUserLocation extends UserLocationNotifier {
  void set(UserLocationState state) => this.state = state;
}

/// Todas las tarjetas de la hoja se pliegan tocando el asa. La única que no
/// es la del bus seleccionado: es la que trae el botón de aviso, y plegarla
/// justo después de tocar el bus escondía lo que el usuario venía a buscar.
void main() {
  const userLat = 6.2442;
  const userLon = -75.5812;

  final bus = BusPosition(
    busId: 'A-1',
    routeId: 'R1',
    lat: userLat + 0.02,
    lon: userLon,
    heading: 0,
    speedKmh: 30,
    timestamp: DateTime.now(),
    isGhostBus: false,
  );

  Future<ProviderContainer> pump(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    // La tarjeta del bus es más alta que los 600 px del lienzo por defecto:
    // el asa quedaría fuera de pantalla y no se podría tocar.
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final container = ProviderContainer(overrides: [
      userLocationProvider.overrideWith((ref) => _TestUserLocation()),
      busPositionsSourceProvider.overrideWith(
        (ref, routeId) => Stream.value([bus]),
      ),
      routeTrajectoryProvider.overrideWith(
        (ref, routeId) => RouteTrajectory(
          routeId: routeId,
          routeName: 'Ruta 1',
          points: const [
            GeoPoint(lat: userLat, lon: userLon - 0.05),
            GeoPoint(lat: userLat, lon: userLon + 0.05),
          ],
        ),
      ),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: EtaBottomSheet())),
      ),
    );
    await tester.pump();
    (container.read(userLocationProvider.notifier) as _TestUserLocation).set(
      const UserLocationState(
        mode: UserLocationMode.manual,
        lat: userLat,
        lon: userLon,
      ),
    );
    // La hoja crece con AnimatedSize anclada abajo: mientras la animación
    // corre, su contenido asoma por encima del borde superior y el asa no se
    // puede tocar. Se espera a que se asiente.
    await tester.pumpAndSettle();
    return container;
  }

  /// El asa de la hoja.
  Finder asa() => find.byKey(const ValueKey('sheet-handle'));

  testWidgets('sin ruta la tarjeta se pliega y se vuelve a abrir',
      (tester) async {
    await pump(tester);
    expect(find.text('Escoge empresa y ruta'), findsOneWidget);

    await tester.tap(asa());
    await tester.pumpAndSettle();
    expect(find.text('Escoge empresa y ruta'), findsNothing,
        reason: 'plegada solo queda el asa');

    await tester.tap(asa());
    await tester.pumpAndSettle();
    expect(find.text('Escoge empresa y ruta'), findsOneWidget);
  });

  testWidgets('con ruta y sin bus la tarjeta también se pliega',
      (tester) async {
    final container = await pump(tester);
    container.read(selectedRouteProvider.notifier).select(
          const RouteInfo(id: 'R1', name: 'Ruta 1', companyId: 'C1'),
        );
    await tester.pumpAndSettle();
    expect(find.text('Toca un bus en el mapa'), findsOneWidget);

    await tester.tap(asa());
    await tester.pumpAndSettle();
    expect(find.text('Toca un bus en el mapa'), findsNothing);
  });

  testWidgets('la tarjeta del bus seleccionado NO se pliega', (tester) async {
    final container = await pump(tester);
    container.read(selectedRouteProvider.notifier).select(
          const RouteInfo(id: 'R1', name: 'Ruta 1', companyId: 'C1'),
        );
    container.read(selectedBusesProvider.notifier).toggleBus('A-1');
    await tester.pumpAndSettle();
    expect(find.textContaining('A-1'), findsWidgets);

    await tester.tap(asa());
    await tester.pumpAndSettle();

    expect(find.textContaining('A-1'), findsWidgets,
        reason: 'tocar el asa no puede esconder el botón de aviso');
  });

  testWidgets('tocar un bus con la hoja plegada la vuelve a abrir',
      (tester) async {
    final container = await pump(tester);
    container.read(selectedRouteProvider.notifier).select(
          const RouteInfo(id: 'R1', name: 'Ruta 1', companyId: 'C1'),
        );
    await tester.pumpAndSettle();
    await tester.tap(asa());
    await tester.pumpAndSettle();

    container.read(selectedBusesProvider.notifier).toggleBus('A-1');
    await tester.pumpAndSettle();

    expect(find.textContaining('A-1'), findsWidgets);
  });
}
