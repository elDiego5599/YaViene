import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/tracking_providers.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/user_location_provider.dart';
import 'package:ya_viene_pasajero/features/notifications/presentation/providers/alert_history_provider.dart';
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
    SharedPreferences.setMockInitialValues({});
    fired = [];
    container = ProviderContainer(overrides: [
      userLocationProvider.overrideWith((ref) => _TestUserLocation()),
      busPositionsSourceProvider.overrideWith(
        (ref, routeId) => Stream.value([busA]),
      ),
      proximityAlertsProvider.overrideWith((ref) {
        return ProximityAlertsNotifier(
          ref,
          notify: (
              {required String busId,
              String? routeName,
              String? routeId,
              required int distanceMeters}) async {
            fired.add((busId: busId, distanceMeters: distanceMeters));
            return true;
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

  test('notifica cuando el bus entra al radio de 1000 m', () async {
    container.read(selectedRouteProvider.notifier).select(route());
    container.read(activeAlertsProvider.notifier).toggleAlert('A-1');

    await container.read(proximityAlertsProvider.notifier).check();

    expect(fired, hasLength(1));
    expect(fired.single.busId, 'A-1');
    expect(fired.single.distanceMeters, lessThan(500));
  });

  // `Timer.periodic` no espera al barrido anterior. Con una notificación
  // lenta (el primer aviso en iOS espera a que se conteste el permiso), el
  // barrido siguiente veía el mismo bus todavía sin marcar y avisaba otra vez.
  test('dos barridos encimados no avisan dos veces el mismo bus', () async {
    final suelta = Completer<bool>();
    var llamadas = 0;
    final c = ProviderContainer(overrides: [
      userLocationProvider.overrideWith((ref) => _TestUserLocation()),
      busPositionsSourceProvider.overrideWith(
        (ref, routeId) => Stream.value([busA]),
      ),
      proximityAlertsProvider.overrideWith((ref) {
        return ProximityAlertsNotifier(
          ref,
          notify: (
              {required String busId,
              String? routeName,
              String? routeId,
              required int distanceMeters}) {
            llamadas++;
            return suelta.future;
          },
        );
      }),
    ]);
    addTearDown(c.dispose);
    (c.read(userLocationProvider.notifier) as _TestUserLocation).set(userHere);
    final sub = c.listen<AsyncValue<List<BusPosition>>>(
      busPositionsSourceProvider('R1'),
      (_, __) {},
    );
    addTearDown(sub.close);
    await Future<void>.delayed(Duration.zero);
    c.read(selectedRouteProvider.notifier).select(route());
    c.read(activeAlertsProvider.notifier).toggleAlert('A-1');

    final notifier = c.read(proximityAlertsProvider.notifier);
    final primero = notifier.check();
    await notifier.check();
    suelta.complete(true);
    await primero;

    expect(llamadas, 1);
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

  test('si la notificación no llegó a mostrarse, el aviso sigue vivo',
      () async {
    // El sistema puede negarse a pintar la notificación (permiso revocado,
    // canal caído). Antes eso se daba por enviado igual: el aviso se
    // marcaba, salía de la lista y el usuario nunca se enteraba de nada. Si
    // no se mostró, todo se queda como estaba y el barrido siguiente lo
    // vuelve a intentar mientras el bus siga dentro del radio.
    var intentos = 0;
    final c = ProviderContainer(overrides: [
      userLocationProvider.overrideWith((ref) => _TestUserLocation()),
      busPositionsSourceProvider.overrideWith(
        (ref, routeId) => Stream.value([busA]),
      ),
      proximityAlertsProvider.overrideWith((ref) {
        return ProximityAlertsNotifier(
          ref,
          notify: (
              {required String busId,
              String? routeName,
              String? routeId,
              required int distanceMeters}) async {
            intentos += 1;
            return false;
          },
        );
      }),
    ]);
    addTearDown(c.dispose);
    (c.read(userLocationProvider.notifier) as _TestUserLocation).set(userHere);
    final keepAlive = c.listen<AsyncValue<List<BusPosition>>>(
      busPositionsSourceProvider('R1'),
      (_, __) {},
    );
    addTearDown(keepAlive.close);
    await Future<void>.delayed(Duration.zero);

    c.read(selectedRouteProvider.notifier).select(route());
    c.read(activeAlertsProvider.notifier).toggleAlert('A-1');
    c.read(proximityAlertsProvider.notifier).armAlert('A-1', 'R1');

    final notifier = c.read(proximityAlertsProvider.notifier);
    await notifier.check();

    expect(intentos, 1);
    expect(c.read(activeAlertsProvider), {'A-1'},
        reason: 'sin notificación mostrada, el aviso no se da por enviado');
    expect(c.read(alertHistoryProvider).single.sent, isFalse);

    // Segundo barrido: se reintenta.
    await notifier.check();
    expect(intentos, 2);
  });

  test('re-armar un aviso disparado limpia la marca y puede volver a sonar',
      () async {
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
      busPositionsSourceProvider
          .overrideWith((ref, routeId) => posController.stream),
      proximityAlertsProvider.overrideWith((ref) {
        return ProximityAlertsNotifier(
          ref,
          notify: (
              {required String busId,
              String? routeName,
              String? routeId,
              required int distanceMeters}) async {
            localFired.add((busId: busId, distanceMeters: distanceMeters));
            return true;
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
    // hoja de la app). El re-arme limpia la marca de "ya notificó": un aviso
    // re-armado nunca debe quedar muerto (BUG: quedaba en `state` y no volvía
    // a sonar aunque el bus entrara otra vez al radio).
    c.read(activeAlertsProvider.notifier).toggleAlert('A-1');
    c.read(proximityAlertsProvider.notifier).armAlert('A-1', 'R1');
    await notifier.check();
    await notifier.check();

    expect(localFired, hasLength(2),
        reason: 'el re-arme limpia el disparo anterior: puede volver a sonar');
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
      busPositionsSourceProvider
          .overrideWith((ref, routeId) => posController.stream),
      proximityAlertsProvider.overrideWith((ref) {
        return ProximityAlertsNotifier(
          ref,
          notify: (
              {required String busId,
              String? routeName,
              String? routeId,
              required int distanceMeters}) async {
            localFired.add((busId: busId, distanceMeters: distanceMeters));
            return true;
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

  test('el ancla del pin sobrevive a cerrar y reabrir la app', () async {
    // Se arma con el pin puesto en la parada (encima del bus).
    (container.read(userLocationProvider.notifier) as _TestUserLocation).set(
      UserLocationState(
        mode: UserLocationMode.manual,
        lat: 6.2442,
        lon: -75.5812,
        updatedAt: DateTime.now(),
      ),
    );
    container.read(selectedRouteProvider.notifier).select(route());
    container.read(activeAlertsProvider.notifier).toggleAlert('A-1');
    container.read(proximityAlertsProvider.notifier).armAlert('A-1', 'R1');
    // Fuerza el vaciado del historial a disco antes de "reabrir".
    await container.read(alertHistoryProvider.notifier).load();

    // Nueva sesión: el notificador arranca vacío y el pin está ahora a ~12 km
    // del bus. El aviso restaurado debe seguir midiendo desde la parada.
    final localFired = <({String busId, int distanceMeters})>[];
    final c = ProviderContainer(overrides: [
      userLocationProvider.overrideWith((ref) {
        final n = _TestUserLocation();
        n.set(UserLocationState(
          mode: UserLocationMode.manual,
          lat: 6.35,
          lon: -75.55,
          updatedAt: DateTime.now(),
        ));
        return n;
      }),
      busPositionsSourceProvider.overrideWith(
        (ref, routeId) => Stream.value([busA]),
      ),
      proximityAlertsProvider.overrideWith((ref) {
        return ProximityAlertsNotifier(
          ref,
          notify: (
              {required String busId,
              String? routeName,
              String? routeId,
              required int distanceMeters}) async {
            localFired.add((busId: busId, distanceMeters: distanceMeters));
            return true;
          },
        );
      }),
    ]);
    addTearDown(c.dispose);
    final sub = c.listen<AsyncValue<List<BusPosition>>>(
      busPositionsSourceProvider('R1'),
      (_, __) {},
    );
    addTearDown(sub.close);
    await Future<void>.delayed(Duration.zero);

    await c.read(proximityAlertsProvider.notifier).restore();
    await c.read(proximityAlertsProvider.notifier).check();

    expect(localFired, hasLength(1),
        reason: 'el aviso mide desde el pin con el que se armó, no del nuevo');
    expect(localFired.single.distanceMeters, lessThan(50));
  });

  test('cada aviso guarda el pin con el que se armó', () async {
    final notifier =
        container.read(userLocationProvider.notifier) as _TestUserLocation;
    container.read(selectedRouteProvider.notifier).select(route());

    notifier.set(UserLocationState(
      mode: UserLocationMode.manual,
      lat: 6.2442,
      lon: -75.5812,
      updatedAt: DateTime.now(),
    ));
    container.read(activeAlertsProvider.notifier).toggleAlert('A-1');
    container.read(proximityAlertsProvider.notifier).armAlert('A-1', 'R1');

    // Se mueve el pin y se arma OTRO bus: este segundo aviso se fija al pin
    // nuevo, y el primero no se entera.
    notifier.set(UserLocationState(
      mode: UserLocationMode.manual,
      lat: 6.35,
      lon: -75.55,
      updatedAt: DateTime.now(),
    ));
    container.read(activeAlertsProvider.notifier).toggleAlert('A-2');
    container.read(proximityAlertsProvider.notifier).armAlert('A-2', 'R1');

    final alerts = container.read(proximityAlertsProvider.notifier);
    expect(alerts.anchorFor('A-1'), (6.2442, -75.5812));
    expect(alerts.anchorFor('A-2'), (6.35, -75.55));
  });
}
