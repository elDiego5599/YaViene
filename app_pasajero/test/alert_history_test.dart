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
  const userLat = 6.2442;
  const userLon = -75.5812;

  RouteInfo routeR1() => const RouteInfo(
        id: 'R1',
        name: 'Ruta 1',
        companyId: 'C1',
      );

  BusPosition busA() => BusPosition(
        busId: 'A-1',
        routeId: 'R1',
        lat: userLat,
        lon: userLon,
        heading: 0,
        speedKmh: 30,
        timestamp: DateTime.now(),
        isGhostBus: false,
      );

  ProviderContainer buildContainer({List<BusPosition>? buses}) {
    final container = ProviderContainer(overrides: [
      userLocationProvider.overrideWith((ref) => _TestUserLocation()),
      busPositionsSourceProvider.overrideWith(
        (ref, routeId) => Stream.value(buses ?? [busA()]),
      ),
    ]);
    (container.read(userLocationProvider.notifier) as _TestUserLocation).set(
      const UserLocationState(
        mode: UserLocationMode.manual,
        lat: userLat,
        lon: userLon,
      ),
    );
    container.read(selectedRouteProvider.notifier).select(routeR1());
    return container;
  }

  void arm(ProviderContainer c, String busId) {
    c.read(activeAlertsProvider.notifier).toggleAlert(busId);
    c.read(proximityAlertsProvider.notifier).armAlert(busId, 'R1');
  }

  /// Deja emitir el stream de posiciones (Stream.value emite por microtask).
  Future<void> drain() => Future<void>.delayed(Duration.zero);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('armar un aviso lo registra en el historial como activo', () {
    final c = buildContainer();
    addTearDown(c.dispose);

    arm(c, 'A-1');

    final history = c.read(alertHistoryProvider);
    expect(history, hasLength(1));
    expect(history.single.busId, 'A-1');
    expect(history.single.sent, isFalse);
  });

  test('re-armar el mismo bus renueva su entrada (una por bus)', () {
    final c = buildContainer();
    addTearDown(c.dispose);

    arm(c, 'A-1');
    c.read(activeAlertsProvider.notifier).toggleAlert('A-1');
    c.read(proximityAlertsProvider.notifier).disarmAlert('A-1');
    c.read(alertHistoryProvider.notifier).remove('A-1');
    arm(c, 'A-1');

    expect(c.read(alertHistoryProvider), hasLength(1));
  });

  test('el disparo pasa la entrada a "enviado"', () async {
    final c = buildContainer();
    addTearDown(c.dispose);

    arm(c, 'A-1');
    await drain();
    await c.read(proximityAlertsProvider.notifier).check();

    final entry = c.read(alertHistoryProvider).single;
    expect(entry.sent, isTrue);
    expect(entry.sentAt, isNotNull);
    expect(c.read(activeAlertsProvider), isEmpty);
  });

  test('desactivar manualmente quita la entrada del historial', () {
    final c = buildContainer();
    addTearDown(c.dispose);

    arm(c, 'A-1');
    c.read(activeAlertsProvider.notifier).toggleAlert('A-1');
    c.read(proximityAlertsProvider.notifier).disarmAlert('A-1');
    c.read(alertHistoryProvider.notifier).remove('A-1');

    expect(c.read(alertHistoryProvider), isEmpty);
    expect(c.read(activeAlertsProvider), isEmpty);
  });

  test('el historial persiste en disco y restore() re-arma los activos',
      () async {
    // Sesión 1: se arma un aviso (queda guardado) y otro dispara (enviado).
    final first = buildContainer();
    addTearDown(first.dispose);
    arm(first, 'A-1');
    await drain();
    await first.read(proximityAlertsProvider.notifier).check();
    first.read(activeAlertsProvider.notifier).toggleAlert('A-1');
    // A-1 ya envió; se arma A-2 y se deja activo. El fixture solo trae a
    // A-1 en el stream, así que A-2 queda esperando.
    arm(first, 'A-2');

    // Sesión 2 (la app se reinició): mismo disco, memoria nueva.
    final second = buildContainer();
    addTearDown(second.dispose);

    await second.read(proximityAlertsProvider.notifier).restore();

    final history = second.read(alertHistoryProvider);
    expect(history, hasLength(2));
    expect(history.firstWhere((e) => e.busId == 'A-1').sent, isTrue);
    expect(history.firstWhere((e) => e.busId == 'A-2').sent, isFalse);
    // Solo el activo se re-armó; el enviado no.
    expect(second.read(activeAlertsProvider), {'A-2'});
  });

  test('restore() es idempotente: no duplica avisos ya armados', () async {
    final c = buildContainer();
    addTearDown(c.dispose);
    arm(c, 'A-2');

    await c.read(proximityAlertsProvider.notifier).restore();
    await c.read(proximityAlertsProvider.notifier).restore();

    expect(c.read(activeAlertsProvider), {'A-2'});
    expect(c.read(alertHistoryProvider), hasLength(1));
  });
}