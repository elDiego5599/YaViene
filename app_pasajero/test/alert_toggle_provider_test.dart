import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/alert_toggle_provider.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/tracking_providers.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/user_location_provider.dart';
import 'package:ya_viene_pasajero/features/notifications/presentation/providers/alert_history_provider.dart';
import 'package:ya_viene_pasajero/features/notifications/presentation/providers/proximity_alerts_provider.dart';

class _TestUserLocation extends UserLocationNotifier {
  void set(UserLocationState state) => this.state = state;
}

const _userLat = 6.2442;
const _userLon = -75.5812;
const _metersPerDegree = 111194.9;

/// Un tramo recto este-oeste que pasa a [km] al norte del usuario.
List<GeoPoint> _routeAtKm(double km) {
  final lat = _userLat + (km * 1000) / _metersPerDegree;
  return [
    GeoPoint(lat: lat, lon: _userLon - 0.05),
    GeoPoint(lat: lat, lon: _userLon + 0.05),
  ];
}

ProviderContainer _container({
  required List<BusPosition> buses,
  required bool permissionGranted,
  NotificationPermissionRequester? requester,
  double routeKm = 0,
}) {
  final c = ProviderContainer(overrides: [
    userLocationProvider.overrideWith((ref) => _TestUserLocation()),
    busPositionsSourceProvider.overrideWith(
      (ref, routeId) => Stream.value(buses),
    ),
    // Por defecto el recorrido pasa por encima del usuario: así estos tests
    // prueban el resto de reglas sin chocar con "esta ruta no pasa cerca".
    routeTrajectoryProvider.overrideWith(
      (ref, routeId) => RouteTrajectory(
        routeId: routeId,
        routeName: 'Ruta 1',
        points: _routeAtKm(routeKm),
      ),
    ),
    proximityAlertsProvider.overrideWith((ref) {
      return ProximityAlertsNotifier(ref,
          notify: (
                  {required String busId,
                  String? routeName,
                  String? routeId,
                  required int distanceMeters}) async =>
              true);
    }),
    alertToggleProvider.overrideWith((ref) => AlertToggleController(
          ref,
          requestPermission: requester ?? (() async => permissionGranted),
        )),
  ]);
  addTearDown(c.dispose);
  return c;
}

void main() {
  final userHere = UserLocationState(
    mode: UserLocationMode.gps,
    lat: _userLat,
    lon: _userLon,
    updatedAt: DateTime.now(),
  );

  // A ~1.9 km del usuario: fuera del radio (1000 m) y fuera del re-arm
  // (1500 m), candidato válido.
  final busLejos = BusPosition(
    busId: 'A-1',
    routeId: 'R1',
    lat: 6.2600,
    lon: -75.5812,
    heading: 0,
    speedKmh: 20,
    timestamp: DateTime.now(),
    isGhostBus: false,
  );

  final busCerca = BusPosition(
    busId: 'C-1',
    routeId: 'R1',
    lat: 6.2442,
    lon: -75.5812,
    heading: 0,
    speedKmh: 20,
    timestamp: DateTime.now(),
    isGhostBus: false,
  );

  final busFantasma = BusPosition(
    busId: 'G-1',
    routeId: 'R1',
    lat: 6.2600,
    lon: -75.5812,
    heading: 0,
    speedKmh: 0,
    timestamp: DateTime.now().subtract(const Duration(minutes: 10)),
    isGhostBus: true,
  );

  RouteInfo route() => const RouteInfo(
        id: 'R1',
        name: 'Ruta 1',
        companyId: 'C1',
      );

  test('activa el aviso cuando todo está en orden y lo arma', () async {
    SharedPreferences.setMockInitialValues({});
    final container = _container(buses: [busLejos], permissionGranted: true);
    (container.read(userLocationProvider.notifier) as _TestUserLocation)
        .set(userHere);
    container.read(selectedRouteProvider.notifier).select(route());
    // El StreamProvider emite en microtasks: se drena antes de tocar para
    // que el guard vea la posición real del bus.
    // listen (no read): autoDispose descarta el provider con un Timer(0) si
    // nadie lo escucha, y el controller re-crearía el stream sin datos.
    final sub = container.listen(busPositionsSourceProvider('R1'), (_, __) {});
    addTearDown(sub.close);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    final result = await container.read(alertToggleProvider).toggle('A-1');

    expect(result.outcome, AlertToggleOutcome.activated);
    expect(container.read(activeAlertsProvider), contains('A-1'));
    // El estado de proximityAlerts son los buses que YA DISPARARON: un aviso
    // recién armado no ha disparado, así que sigue vacío (lo observable del
    // armado es que activeAlerts lo contiene y que no lanzó excepción).
    expect(container.read(proximityAlertsProvider), isEmpty);
  });

  // El bug reportado: el recorrido rozaba el anillo de 2 km, la app dejaba
  // armar y el aviso solo suena a 1 km. Quedaba «AVISO ACTIVADO» para siempre.
  test('un recorrido que nunca entra en el radio de disparo no se arma',
      () async {
    SharedPreferences.setMockInitialValues({});
    final container = _container(
      buses: [busLejos],
      permissionGranted: true,
      routeKm: 1.5,
    );
    (container.read(userLocationProvider.notifier) as _TestUserLocation)
        .set(userHere);
    container.read(selectedRouteProvider.notifier).select(route());
    final sub = container.listen(busPositionsSourceProvider('R1'), (_, __) {});
    addTearDown(sub.close);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    final result = await container.read(alertToggleProvider).toggle('A-1');

    expect(result.outcome, AlertToggleOutcome.rejected);
    expect(result.message, contains('no pasa cerca de ti'));
    expect(result.message, contains('1,5 km'));
    expect(container.read(activeAlertsProvider), isEmpty);
  });

  test('sin ubicación lo rechaza explicando qué falta', () async {
    SharedPreferences.setMockInitialValues({});
    final container = _container(buses: [busLejos], permissionGranted: true);
    (container.read(userLocationProvider.notifier) as _TestUserLocation)
        .set(UserLocationState(
      mode: UserLocationMode.denied,
      updatedAt: DateTime.now(),
    ));
    container.read(selectedRouteProvider.notifier).select(route());

    final result = await container.read(alertToggleProvider).toggle('A-1');

    expect(result.outcome, AlertToggleOutcome.rejected);
    expect(result.message, contains('dónde estás'));
    expect(container.read(activeAlertsProvider), isEmpty);
  });

  test('un bus fantasma (sin señal) no se puede armar', () async {
    SharedPreferences.setMockInitialValues({});
    final container = _container(buses: [busFantasma], permissionGranted: true);
    (container.read(userLocationProvider.notifier) as _TestUserLocation)
        .set(userHere);
    container.read(selectedRouteProvider.notifier).select(route());
    // listen (no read): autoDispose descarta el provider con un Timer(0) si
    // nadie lo escucha, y el controller re-crearía el stream sin datos.
    final sub = container.listen(busPositionsSourceProvider('R1'), (_, __) {});
    addTearDown(sub.close);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    final result = await container.read(alertToggleProvider).toggle('G-1');

    expect(result.outcome, AlertToggleOutcome.rejected);
    expect(result.message, contains('sin señal'));
    expect(container.read(activeAlertsProvider), isEmpty);
  });

  test('un bus ya dentro del radio no acepta aviso', () async {
    SharedPreferences.setMockInitialValues({});
    final container = _container(buses: [busCerca], permissionGranted: true);
    (container.read(userLocationProvider.notifier) as _TestUserLocation)
        .set(userHere);
    container.read(selectedRouteProvider.notifier).select(route());
    // listen (no read): autoDispose descarta el provider con un Timer(0) si
    // nadie lo escucha, y el controller re-crearía el stream sin datos.
    final sub = container.listen(busPositionsSourceProvider('R1'), (_, __) {});
    addTearDown(sub.close);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    final result = await container.read(alertToggleProvider).toggle('C-1');

    expect(result.outcome, AlertToggleOutcome.rejected);
    expect(result.message, contains('ya está a menos de'));
    expect(container.read(activeAlertsProvider), isEmpty);
  });

  test('sin permiso de notificaciones no se arma nada', () async {
    SharedPreferences.setMockInitialValues({});
    final container = _container(buses: [busLejos], permissionGranted: false);
    (container.read(userLocationProvider.notifier) as _TestUserLocation)
        .set(userHere);
    container.read(selectedRouteProvider.notifier).select(route());

    final result = await container.read(alertToggleProvider).toggle('A-1');

    expect(result.outcome, AlertToggleOutcome.permissionDenied);
    expect(container.read(activeAlertsProvider), isEmpty);
    expect(container.read(proximityAlertsProvider), isEmpty);
  });

  test('desactivar un aviso activo lo desarma completo', () async {
    SharedPreferences.setMockInitialValues({});
    final container = _container(buses: [busLejos], permissionGranted: true);
    (container.read(userLocationProvider.notifier) as _TestUserLocation)
        .set(userHere);
    container.read(selectedRouteProvider.notifier).select(route());

    await container.read(alertToggleProvider).toggle('A-1');
    expect(container.read(activeAlertsProvider), contains('A-1'));
    // `load()` espera a que termine la escritura y relee del disco: lo que
    // devuelve es lo que vería la app al reabrirse.
    final history = container.read(alertHistoryProvider.notifier);
    await history.load();
    expect(container.read(alertHistoryProvider).map((e) => e.busId),
        contains('A-1'));

    final result = await container.read(alertToggleProvider).toggle('A-1');
    expect(result.outcome, AlertToggleOutcome.deactivated);
    expect(container.read(activeAlertsProvider), isEmpty);
    expect(container.read(proximityAlertsProvider), isEmpty);
    // El historial es la única persistencia de los avisos activos: si la
    // entrada siguiera en disco, el aviso se volvería a armar al reabrir.
    await history.load();
    expect(container.read(alertHistoryProvider), isEmpty);
  });

  test('la carrera de dos taps no supera el límite: limitReached', () async {
    SharedPreferences.setMockInitialValues({});
    // El requester simula la carrera: mientras el permiso "viaja", el tap
    // concurrente ocupa el cupo. La comprobación atómica debe defenderlo.
    ProviderContainer? race;
    final container = _container(
      buses: [busLejos],
      permissionGranted: true,
      requester: () async {
        final alerts = race!.read(activeAlertsProvider.notifier);
        alerts.activateAlert('X-1');
        alerts.activateAlert('X-2');
        return true;
      },
    );
    race = container;
    (container.read(userLocationProvider.notifier) as _TestUserLocation)
        .set(userHere);
    container.read(selectedRouteProvider.notifier).select(route());

    final result = await container.read(alertToggleProvider).toggle('A-1');

    expect(result.outcome, AlertToggleOutcome.limitReached);
    expect(result.message, contains('2 avisos activos'));
    expect(container.read(activeAlertsProvider), isNot(contains('A-1')));
  });

  test('aviso activado sin ruta se deshace solo (estado imposible)', () async {
    SharedPreferences.setMockInitialValues({});
    final container = _container(buses: [busLejos], permissionGranted: true);
    (container.read(userLocationProvider.notifier) as _TestUserLocation)
        .set(userHere);
    // Sin ruta seleccionada: el caso imposible.
    container.read(selectedRouteProvider.notifier).clear();

    final result = await container.read(alertToggleProvider).toggle('A-1');

    expect(result.outcome, AlertToggleOutcome.noRoute);
    // En ningún caso queda un aviso huérfano.
    expect(container.read(activeAlertsProvider), isEmpty);
  });
}
