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
  late ProviderContainer container;

  RouteInfo routeR1() => const RouteInfo(
        id: 'R1',
        name: 'Ruta 1',
        companyId: 'C1',
      );

  RouteInfo routeR2() => const RouteInfo(
        id: 'R2',
        name: 'Ruta 2',
        companyId: 'C1',
      );

  setUp(() {
    container = ProviderContainer(overrides: [
      userLocationProvider.overrideWith((ref) => _TestUserLocation()),
      busPositionsSourceProvider.overrideWith(
        (ref, routeId) => Stream.value(const <BusPosition>[]),
      ),
    ]);
    addTearDown(container.dispose);
  });

  Future<void> pumpSheet(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: EtaBottomSheet()),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('cambiar de ruta no cancela el aviso armado (BUG-03)', (tester) async {
    await pumpSheet(tester);
    (container.read(userLocationProvider.notifier) as _TestUserLocation).set(
      const UserLocationState(
        mode: UserLocationMode.manual,
        lat: 6.2442,
        lon: -75.5812,
      ),
    );
    container.read(selectedRouteProvider.notifier).select(routeR1());
    container.read(activeAlertsProvider.notifier).toggleAlert('A-1');
    container.read(proximityAlertsProvider.notifier).armAlert('A-1', 'R1');
    await tester.pump();

    expect(container.read(activeAlertsProvider), contains('A-1'));

    // El usuario cambia la ruta en pantalla: el aviso debe sobrevivir.
    container.read(selectedRouteProvider.notifier).select(routeR2());
    await tester.pump();

    expect(container.read(activeAlertsProvider), contains('A-1'),
        reason: 'cambiar de ruta no debe cancelar el aviso');
  });

  testWidgets('perder la ubicación no cancela el aviso armado (BUG-03)', (tester) async {
    await pumpSheet(tester);
    (container.read(userLocationProvider.notifier) as _TestUserLocation).set(
      const UserLocationState(
        mode: UserLocationMode.manual,
        lat: 6.2442,
        lon: -75.5812,
      ),
    );
    container.read(selectedRouteProvider.notifier).select(routeR1());
    container.read(activeAlertsProvider.notifier).toggleAlert('A-1');
    container.read(proximityAlertsProvider.notifier).armAlert('A-1', 'R1');
    await tester.pump();

    expect(container.read(activeAlertsProvider), contains('A-1'));

    // El usuario quita el pin (sin GPS): la selección visual se limpia pero
    // el aviso queda armado; se pausa y reanuda cuando vuelva la ubicación.
    (container.read(userLocationProvider.notifier) as _TestUserLocation).set(
      const UserLocationState(mode: UserLocationMode.denied),
    );
    await tester.pump();

    expect(container.read(activeAlertsProvider), contains('A-1'),
        reason: 'perder la ubicación no debe cancelar el aviso');
  });
}