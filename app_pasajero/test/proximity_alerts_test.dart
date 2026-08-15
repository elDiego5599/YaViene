import 'dart:async';

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

  test('al notificar, el bus sale de la lista de alertas activas', () async {
    container.read(selectedRouteProvider.notifier).select(route());
    container.read(activeAlertsProvider.notifier).toggleAlert('A-1');

    await container.read(proximityAlertsProvider.notifier).check();

    expect(fired, hasLength(1));
    expect(container.read(activeAlertsProvider), isEmpty);
  });

  test('re-arma el aviso no vuelve a disparar mientras el bus sigue cerca '
      '(histéresis con rearm > radio)', () async {
    // Bus a ~800 m: dentro del radio de alerta (1000 m) pero por debajo del
    // radio de rearm (1500 m). Con la histéresis invertida este caso
    // re-disparaba en bucle cada vez que se re-armaba.
    final busAt800m = BusPosition(
      busId: 'A-1',
      routeId: 'R1',
      lat: 6.2514,
      lon: -75.5812,
      heading: 0,
      speedKmh: 20,
      timestamp: DateTime.now(),
      isGhostBus: false,
    );
    final posController = StreamController<List<BusPosition>>.broadcast();
    final localFired = <({String busId, int distanceMeters})>[];
    final c = ProviderContainer(overrides: [
      userLocationProvider.overrideWith((ref) {
        final n = _TestUserLocation();
        n.set(userHere);
        return n;
      }),
      busPositionsSourceProvider.overrideWith(
          (ref, routeId) => posController.stream),
      proximityAlertsProvider.overrideWith((ref) {
        return ProximityAlertsNotifier(
          ref,
          notify: ({required String busId, required int distanceMeters}) async {
            localFired.add((busId: busId, distanceMeters: distanceMeters));
          },
        );
      }),
    ]);
    addTearDown(c.dispose);
    // La app mantiene viva la suscripción de la ruta activa (mapa/hoja); el
    // test la imita para que las posiciones sigan disponibles tras disparar.
    final keepAlive = c.listen<AsyncValue<List<BusPosition>>>(
      busPositionsSourceProvider('R1'),
      (_, __) {},
    );
    addTearDown(keepAlive.close);
    c.read(selectedRouteProvider.notifier).select(route());
    c.read(activeAlertsProvider.notifier).toggleAlert('A-1');
    c.read(proximityAlertsProvider.notifier).armAlert('A-1', 'R1');

    posController.add([busAt800m]);
    await Future<void>.delayed(Duration.zero);

    final notifier = c.read(proximityAlertsProvider.notifier);
    await notifier.check();
    expect(localFired, hasLength(1));

    // Al disparar, el bus salió de las alertas; el usuario lo re-arma con el
    // bus todavía cerca (el re-arme vuelve a registrar la ruta, como en la
    // hoja de la app).
    c.read(activeAlertsProvider.notifier).toggleAlert('A-1');
    c.read(proximityAlertsProvider.notifier).armAlert('A-1', 'R1');
    await notifier.check();
    await notifier.check();

    expect(localFired, hasLength(1), reason: 'no debe re-disparar sin rearmar');
    await posController.close();
  });

  test('el aviso armado con pin manual sigue sonando si luego quitan el pin',
      () async {
    // Usuario con pin manual en su parada (sin permiso de GPS).
    final notifier =
        container.read(userLocationProvider.notifier) as _TestUserLocation;
    notifier.set(UserLocationState(
      mode: UserLocationMode.manual,
      lat: 6.2442,
      lon: -75.5812,
      updatedAt: DateTime.now(),
    ));
    container.read(selectedRouteProvider.notifier).select(route());
    container.read(activeAlertsProvider.notifier).toggleAlert('A-1');
    container.read(proximityAlertsProvider.notifier).armAlert('A-1', 'R1');

    // Quitan el pin y no hay GPS: la app se queda sin ubicación (BUG: el
    // aviso quedaba congelado, "activo" pero sin sonar nunca).
    notifier.set(const UserLocationState(mode: UserLocationMode.denied));

    await container.read(proximityAlertsProvider.notifier).check();

    expect(fired, hasLength(1), reason: 'el aviso debe sonar con el ancla');
    expect(fired.single.busId, 'A-1');
  });

  test('un pin nuevo NO mueve un aviso ya armado con otro pin', () async {
    final notifier =
        container.read(userLocationProvider.notifier) as _TestUserLocation;
    // Pin en la parada original.
    notifier.set(UserLocationState(
      mode: UserLocationMode.manual,
      lat: 6.2442,
      lon: -75.5812,
      updatedAt: DateTime.now(),
    ));
    container.read(selectedRouteProvider.notifier).select(route());
    container.read(activeAlertsProvider.notifier).toggleAlert('A-1');
    container.read(proximityAlertsProvider.notifier).armAlert('A-1', 'R1');

    // Pin nuevo a ~12 km: lejos del bus. El aviso debe seguir midiendo desde
    // la parada original (donde se armó), no desde el pin nuevo.
    notifier.set(UserLocationState(
      mode: UserLocationMode.manual,
      lat: 6.35,
      lon: -75.55,
      updatedAt: DateTime.now(),
    ));

    await container.read(proximityAlertsProvider.notifier).check();

    expect(fired, hasLength(1));
    expect(fired.single.busId, 'A-1');
  });

  test('el aviso mide en la ruta del bus aunque la pantalla muestre otra',
      () async {
    // Bus A-2 pertenece a R2, pero la ruta seleccionada es R1: el aviso debe
    // disparar igual (BUG-07).
    final busB = BusPosition(
      busId: 'A-2',
      routeId: 'R2',
      lat: 6.2442,
      lon: -75.5812,
      heading: 0,
      speedKmh: 20,
      timestamp: DateTime.now(),
      isGhostBus: false,
    );
    final posController = StreamController<List<BusPosition>>.broadcast();
    final localFired = <({String busId, int distanceMeters})>[];
    final c = ProviderContainer(overrides: [
      userLocationProvider.overrideWith((ref) {
        final n = _TestUserLocation();
        n.set(userHere);
        return n;
      }),
      busPositionsSourceProvider.overrideWith(
          (ref, routeId) => posController.stream),
      proximityAlertsProvider.overrideWith((ref) {
        return ProximityAlertsNotifier(
          ref,
          notify: ({required String busId, required int distanceMeters}) async {
            localFired.add((busId: busId, distanceMeters: distanceMeters));
          },
        );
      }),
    ]);
    addTearDown(c.dispose);

    // La pantalla muestra R1; el aviso se arma para A-2 de R2.
    c.read(selectedRouteProvider.notifier).select(route());
    c.read(activeAlertsProvider.notifier).toggleAlert('A-2');
    c.read(proximityAlertsProvider.notifier).armAlert('A-2', 'R2');
    posController.add([busB]);
    await Future<void>.delayed(Duration.zero);

    await c.read(proximityAlertsProvider.notifier).check();

    expect(localFired, hasLength(1));
    expect(localFired.single.busId, 'A-2');
    await posController.close();
  });
}
