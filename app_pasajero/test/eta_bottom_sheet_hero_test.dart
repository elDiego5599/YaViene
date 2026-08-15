import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import 'package:ya_viene_pasajero/features/map/presentation/widgets/eta_bottom_sheet.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/tracking_providers.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/user_location_provider.dart';
import 'package:ya_viene_pasajero/features/notifications/presentation/providers/proximity_alerts_provider.dart';

class _TestUserLocation extends UserLocationNotifier {
  void set(UserLocationState state) => this.state = state;
}

void main() {
  const userLat = 6.2442;
  const userLon = -75.5812;

  RouteInfo routeR1() => const RouteInfo(
        id: 'R1',
        name: 'Ruta 1',
        companyId: 'C1',
      );

  BusPosition busAt(double latOffset) => BusPosition(
        busId: 'A-1',
        routeId: 'R1',
        lat: userLat + latOffset,
        lon: userLon,
        heading: 0,
        speedKmh: 30,
        timestamp: DateTime.now(),
        isGhostBus: false,
      );

  Future<ProviderContainer> pumpHero(
      WidgetTester tester, List<BusPosition> buses) async {
    final container = ProviderContainer(overrides: [
      userLocationProvider.overrideWith((ref) => _TestUserLocation()),
      busPositionsSourceProvider.overrideWith(
        (ref, routeId) => Stream.value(buses),
      ),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: EtaBottomSheet()),
        ),
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
    container.read(selectedRouteProvider.notifier).select(routeR1());
    container.read(selectedBusesProvider.notifier).toggleBus('A-1');
    await tester.pump();
    await tester.pump();
    return container;
  }

  testWidgets('hero card: métrica grande en metros (850 m de ti)', (tester) async {
    await pumpHero(tester, [busAt(0.007645)]);

    expect(find.text('Bus A-1 · Ruta 1'), findsOneWidget);
    expect(find.text('850'), findsOneWidget,
        reason: 'el número es la métrica principal del hero');
    expect(find.text('m de ti'), findsOneWidget);
  });

  testWidgets('hero card: métrica en kilómetros (2.2 km de ti)', (tester) async {
    await pumpHero(tester, [busAt(0.02)]);

    expect(find.text('2.2'), findsOneWidget);
    expect(find.text('km de ti'), findsOneWidget);
  });

  testWidgets('hero card: bus va pasando (sin métrica, palabra de estado)',
      (tester) async {
    await pumpHero(tester, [busAt(0.002)]);

    expect(find.text('Va pasando'), findsOneWidget);
    expect(find.text('BUS VA PASANDO'), findsOneWidget);
  });

  testWidgets('hero card: sin ubicación muestra estado y no métrica',
      (tester) async {
    final container = ProviderContainer(overrides: [
      userLocationProvider.overrideWith((ref) => _TestUserLocation()),
      busPositionsSourceProvider.overrideWith(
        (ref, routeId) => Stream.value([busAt(0.007645)]),
      ),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: EtaBottomSheet()),
        ),
      ),
    );
    await tester.pump();
    container.read(selectedRouteProvider.notifier).select(routeR1());
    container.read(selectedBusesProvider.notifier).toggleBus('A-1');
    await tester.pump();
    await tester.pump();

    expect(find.text('Sin tu ubicación'), findsOneWidget);
    expect(find.text('Toca el mapa para indicar dónde estás'), findsOneWidget);
  });

  testWidgets('hero card: con aviso activo la franja pasa a verde', (tester) async {
    final container = await pumpHero(tester, [busAt(0.02)]);
    container.read(activeAlertsProvider.notifier).toggleAlert('A-1');
    container.read(proximityAlertsProvider.notifier).armAlert('A-1', 'R1');
    await tester.pump();

    expect(find.text('AVISO ACTIVADO'), findsOneWidget);
    expect(
        find.text('No cierres la aplicación para que la notificación te llegue'),
        findsOneWidget);
  });
}