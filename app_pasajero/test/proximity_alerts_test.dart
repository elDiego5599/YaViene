import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/tracking_providers.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/user_location_provider.dart';
import 'package:ya_viene_pasajero/features/notifications/presentation/providers/proximity_alerts_provider.dart';

class _TestUserLocation extends UserLocationNotifier {
  void set(UserLocationState state) => this.state = state;
}

void main() {
  late ProviderContainer container;
  late List<({String busId, int distanceMeters})> fired;

  final busA = BusPosition(
    busId: 'A-1',
    routeId: 'R1',
    lat: 6.2442,
    lon: -75.5812,
    heading: 0,
    speedKmh: 20,
    timestamp: DateTime.now(),
    isGhostBus: false,
  );

  final userHere = UserLocationState(
    mode: UserLocationMode.gps,
    lat: 6.2442,
    lon: -75.5812,
    updatedAt: DateTime.now(),
  );

  RouteInfo route() => const RouteInfo(
        id: 'R1',
        name: 'Ruta 1',
        companyId: 'C1',
      );

  setUp(() async {
    fired = [];
    container = ProviderContainer(overrides: [
      userLocationProvider.overrideWith((ref) => _TestUserLocation()),
      busPositionsSourceProvider.overrideWith(
        (ref, routeId) => Stream.value([busA]),
      ),
      proximityAlertsProvider.overrideWith((ref) {
        return ProximityAlertsNotifier(
          ref,
          notify: ({required String busId, required int distanceMeters}) async {
            fired.add((busId: busId, distanceMeters: distanceMeters));
          },
        );
      }),
    ]);
    (container.read(userLocationProvider.notifier) as _TestUserLocation)
        .set(userHere);
    // Suscribe y deja emitir el stream de posiciones para que el lector
    // posterior encuentre el valor cacheado.
    final sub = container.listen<AsyncValue<List<BusPosition>>>(
      busPositionsSourceProvider('R1'),
      (_, __) {},
    );
    addTearDown(sub.close);
    await Future<void>.delayed(Duration.zero);
  });

  tearDown(() => container.dispose());

  test('notifica cuando el bus entra al radio de 500 m', () async {
    container.read(selectedRouteProvider.notifier).select(route());
    container.read(activeAlertsProvider.notifier).toggleAlert('A-1');

    await container.read(proximityAlertsProvider.notifier).check();

    expect(fired, hasLength(1));
    expect(fired.single.busId, 'A-1');
    expect(fired.single.distanceMeters, lessThan(500));
  });

  test('no notifica dos veces por el mismo acercamiento', () async {
    container.read(selectedRouteProvider.notifier).select(route());
    container.read(activeAlertsProvider.notifier).toggleAlert('A-1');

    final notifier = container.read(proximityAlertsProvider.notifier);
    await notifier.check();
    await notifier.check();
    await notifier.check();

    expect(fired, hasLength(1));
  });

  test('no notifica si no hay ruta seleccionada', () {
    container.read(activeAlertsProvider.notifier).toggleAlert('A-1');

    expect(fired, isEmpty);
  });

  test('no notifica un bus sin alerta', () async {
    container.read(selectedRouteProvider.notifier).select(route());

    await container.read(proximityAlertsProvider.notifier).check();

    expect(fired, isEmpty);
  });
}
