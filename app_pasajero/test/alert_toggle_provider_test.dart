import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/alert_toggle_provider.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/tracking_providers.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/user_location_provider.dart';
import 'package:ya_viene_pasajero/features/notifications/presentation/providers/alert_history_provider.dart';
import 'package:ya_viene_pasajero/features/notifications/presentation/providers/distancia_aviso_provider.dart';
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

/// La rueda contestada con [metros] «solo esta vez».
ElegirDistancia _unaVez(int metros) =>
    (_, __) async => (metros: metros, guardar: false);

/// Una rueda que no debía abrirse.
Future<({int metros, bool guardar})?> _noPreguntes(int? _, int? __) async =>
    fail('no debía preguntar la distancia');

ProviderContainer _container({
  required List<BusPosition> buses,
  required bool permissionGranted,
  NotificationPermissionRequester? requester,
  double routeKm = 0,
  List<GeoPoint>? ruta,
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
        points: ruta ?? _routeAtKm(routeKm),
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

    final result = await container
        .read(alertToggleProvider)
        .toggle('A-1', elegirDistancia: _unaVez(1000));

    expect(result.outcome, AlertToggleOutcome.activated);
    expect(container.read(activeAlertsProvider), contains('A-1'));
    // El estado de proximityAlerts son los buses que YA DISPARARON: un aviso
    // recién armado no ha disparado, así que sigue vacío (lo observable del
    // armado es que activeAlerts lo contiene y que no lanzó excepción).
    expect(container.read(proximityAlertsProvider), isEmpty);
  });

  // El bug reportado: el recorrido rozaba el anillo de 2 km, la app dejaba
  // armar y el aviso solo suena a 1 km. Quedaba «AVISO ACTIVADO» para siempre.
  // La rueda ya no ofrece 1 km con la ruta a 1,45; si aun así llega, no se
  // arma.
  test('un recorrido que nunca entra en el radio de disparo no se arma',
      () async {
    SharedPreferences.setMockInitialValues({});
    final container = _container(
      buses: [busLejos],
      permissionGranted: true,
      routeKm: 1.45,
    );
    (container.read(userLocationProvider.notifier) as _TestUserLocation)
        .set(userHere);
    container.read(selectedRouteProvider.notifier).select(route());
    final sub = container.listen(busPositionsSourceProvider('R1'), (_, __) {});
    addTearDown(sub.close);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    final result = await container
        .read(alertToggleProvider)
        .toggle('A-1', elegirDistancia: _unaVez(1000));

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

    final result = await container
        .read(alertToggleProvider)
        .toggle('A-1', elegirDistancia: _unaVez(1000));

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

    final result = await container
        .read(alertToggleProvider)
        .toggle('G-1', elegirDistancia: _unaVez(1000));

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

    final result = await container
        .read(alertToggleProvider)
        .toggle('C-1', elegirDistancia: _unaVez(1000));

    expect(result.outcome, AlertToggleOutcome.rejected);
    expect(result.message, contains('ya está a menos de'));
    expect(container.read(activeAlertsProvider), isEmpty);
  });

  // Riesgo: medir «ya está cerca» con otra vara que el aviso. A 900 m un
  // aviso de 1 km sonaría ya mismo: no se arma. Uno de 800 m todavía no ha
  // sonado: se arma.
  test('«ya está cerca» se mide con la distancia elegida', () async {
    for (final (metros, esperado) in [
      (1000, AlertToggleOutcome.rejected),
      (800, AlertToggleOutcome.activated),
    ]) {
      SharedPreferences.setMockInitialValues({});
      final container = _container(
          buses: [busLejos.copyWith(lat: 6.2523)], // ≈ 900 m
          permissionGranted: true);
      (container.read(userLocationProvider.notifier) as _TestUserLocation)
          .set(userHere);
      container.read(selectedRouteProvider.notifier).select(route());
      final sub =
          container.listen(busPositionsSourceProvider('R1'), (_, __) {});
      addTearDown(sub.close);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      final result = await container
          .read(alertToggleProvider)
          .toggle('A-1', elegirDistancia: _unaVez(metros));

      expect(result.outcome, esperado, reason: 'aviso a $metros m');
      if (esperado == AlertToggleOutcome.rejected) {
        expect(result.message, contains('ya está a menos de 1,0 km'));
      }
    }
  });

  test('sin permiso de notificaciones no se arma nada', () async {
    SharedPreferences.setMockInitialValues({});
    final container = _container(buses: [busLejos], permissionGranted: false);
    (container.read(userLocationProvider.notifier) as _TestUserLocation)
        .set(userHere);
    container.read(selectedRouteProvider.notifier).select(route());

    final result = await container
        .read(alertToggleProvider)
        .toggle('A-1', elegirDistancia: _unaVez(1000));

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

    await container
        .read(alertToggleProvider)
        .toggle('A-1', elegirDistancia: _unaVez(1000));
    expect(container.read(activeAlertsProvider), contains('A-1'));
    // `load()` espera a que termine la escritura y relee del disco: lo que
    // devuelve es lo que vería la app al reabrirse.
    final history = container.read(alertHistoryProvider.notifier);
    await history.load();
    expect(container.read(alertHistoryProvider).map((e) => e.busId),
        contains('A-1'));

    final result = await container
        .read(alertToggleProvider)
        .toggle('A-1', elegirDistancia: _unaVez(1000));
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

    final result = await container
        .read(alertToggleProvider)
        .toggle('A-1', elegirDistancia: _unaVez(1000));

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

    final result = await container
        .read(alertToggleProvider)
        .toggle('A-1', elegirDistancia: _unaVez(1000));

    expect(result.outcome, AlertToggleOutcome.noRoute);
    // En ningún caso queda un aviso huérfano.
    expect(container.read(activeAlertsProvider), isEmpty);
  });

  // La distancia la pone la persona (dueño, 2026-10-06): la primera vez que
  // activa un aviso sale la rueda, y puede usarla «solo esta vez» o
  // guardarla para los que vienen.
  group('la distancia del aviso', () {
    Future<ProviderContainer> listo({
      List<BusPosition>? buses,
      double routeKm = 0,
      Map<String, Object> guardado = const {},
      bool located = true,
    }) async {
      SharedPreferences.setMockInitialValues(guardado);
      final container = _container(
        // A ≈ 4 km: fuera de cualquier distancia de la rueda.
        buses: buses ?? [busLejos.copyWith(lat: 6.2800)],
        permissionGranted: true,
        routeKm: routeKm,
      );
      (container.read(userLocationProvider.notifier) as _TestUserLocation).set(
          located
              ? userHere
              : UserLocationState(
                  mode: UserLocationMode.denied, updatedAt: DateTime.now()));
      container.read(selectedRouteProvider.notifier).select(route());
      final sub =
          container.listen(busPositionsSourceProvider('R1'), (_, __) {});
      addTearDown(sub.close);
      await container.read(distanciaAvisoProvider.notifier).load();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      return container;
    }

    test('sin distancia guardada pregunta; «solo esta vez» no la guarda',
        () async {
      final container = await listo();
      var preguntas = 0;
      int? tope = -1;

      final result = await container.read(alertToggleProvider).toggle('A-1',
          elegirDistancia: (_, hasta) async {
        preguntas++;
        tope = hasta;
        return (metros: 1800, guardar: false);
      });

      expect(result.outcome, AlertToggleOutcome.activated);
      expect(preguntas, 1);
      expect(tope, isNull, reason: 'con el bus a 4 km la rueda va entera');
      expect(container.read(proximityAlertsProvider.notifier).radioDe('A-1'),
          1800);
      expect(container.read(distanciaAvisoProvider), isNull);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('distancia_aviso_m'), isFalse);
    });

    test('«Guardar» la deja para los avisos que vienen y arma con ella',
        () async {
      final container = await listo();

      final result = await container.read(alertToggleProvider).toggle('A-1',
          elegirDistancia: (_, __) async => (metros: 2200, guardar: true));

      expect(result.outcome, AlertToggleOutcome.activated);
      expect(container.read(proximityAlertsProvider.notifier).radioDe('A-1'),
          2200);
      expect(container.read(distanciaAvisoProvider), 2200);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('distancia_aviso_m'), 2200);
    });

    test('con una distancia guardada no pregunta y arma con ella', () async {
      final container = await listo(guardado: {'distancia_aviso_m': 1500});

      final result = await container
          .read(alertToggleProvider)
          .toggle('A-1', elegirDistancia: _noPreguntes);

      expect(result.outcome, AlertToggleOutcome.activated);
      expect(container.read(proximityAlertsProvider.notifier).radioDe('A-1'),
          1500);
    });

    // Con 1 km guardado y el bus a 830 m, el aviso de 1 km sonaría ya
    // mismo, pero uno de 500 m todavía sirve: no se dice «ya está cerca»,
    // se pregunta con la rueda topada 200 m por debajo del bus (dueño,
    // 2026-10-07: «si ya viene a menos de 1 km no puede poner aviso para
    // 1 km o más, y así con todos»).
    test('con la guardada por encima del bus, la rueda solo ofrece menos',
        () async {
      final container = await listo(
        buses: [busLejos.copyWith(lat: 6.2517)], // ≈ 834 m
        guardado: {'distancia_aviso_m': 1000},
      );
      int? tope;

      final result = await container.read(alertToggleProvider).toggle('A-1',
          elegirDistancia: (_, hasta) async {
        tope = hasta;
        return (metros: 500, guardar: false);
      });

      expect(tope, 600);
      expect(result.outcome, AlertToggleOutcome.activated);
      expect(
          container.read(proximityAlertsProvider.notifier).radioDe('A-1'), 500);
      expect(container.read(distanciaAvisoProvider), 1000,
          reason: '«Solo esta vez» no toca la guardada');
    });

    test('sin guardada y con el bus a 834 m, la rueda llega a 600 m', () async {
      final container =
          await listo(buses: [busLejos.copyWith(lat: 6.2517)]); // ≈ 834 m
      int? tope;

      await container.read(alertToggleProvider).toggle('A-1',
          elegirDistancia: (_, hasta) async {
        tope = hasta;
        return null;
      });

      expect(tope, 600);
    });

    test('cerrar la rueda sin elegir no arma nada ni vibra', () async {
      final container = await listo();

      final result = await container
          .read(alertToggleProvider)
          .toggle('A-1', elegirDistancia: (_, __) async => null);

      expect(result.outcome, AlertToggleOutcome.cancelled);
      expect(result.needsHaptic, isFalse);
      expect(container.read(activeAlertsProvider), isEmpty);
      expect(container.read(alertHistoryProvider), isEmpty);
    });

    test('desactivar no pregunta la distancia', () async {
      final container = await listo();
      final toggle = container.read(alertToggleProvider);
      await toggle.toggle('A-1', elegirDistancia: _unaVez(1000));

      final result = await toggle.toggle('A-1', elegirDistancia: _noPreguntes);

      expect(result.outcome, AlertToggleOutcome.deactivated);
    });

    // Preguntar una distancia para luego decir que no se puede sería hacerle
    // perder el tiempo: lo que ninguna opción de la rueda arregla se dice
    // antes de abrirla.
    group('lo que ninguna distancia arregla se dice sin preguntar', () {
      test('sin ubicación', () async {
        final container = await listo(located: false);
        final result = await container
            .read(alertToggleProvider)
            .toggle('A-1', elegirDistancia: _noPreguntes);
        expect(result.outcome, AlertToggleOutcome.rejected);
        expect(result.message, contains('dónde estás'));
      });

      // A 645 m, ni el aviso de 500 m deja los 200 m de margen.
      test('el bus ya está más cerca que 700 m', () async {
        final container =
            await listo(buses: [busLejos.copyWith(lat: 6.2500)]); // ≈ 645 m
        final result = await container
            .read(alertToggleProvider)
            .toggle('A-1', elegirDistancia: _noPreguntes);
        expect(result.outcome, AlertToggleOutcome.rejected);
        expect(result.message, contains('ya está a menos de 700 m'));
      });

      test('la ruta no entra ni a 3 km', () async {
        final container = await listo(routeKm: 3.4);
        final result = await container
            .read(alertToggleProvider)
            .toggle('A-1', elegirDistancia: _noPreguntes);
        expect(result.outcome, AlertToggleOutcome.rejected);
        expect(result.message, contains('3 km como mucho'));
      });

      test('ya hay 2 avisos activos', () async {
        final container = await listo();
        final alerts = container.read(activeAlertsProvider.notifier);
        alerts.activateAlert('X-1');
        alerts.activateAlert('X-2');
        final result = await container
            .read(alertToggleProvider)
            .toggle('A-1', elegirDistancia: _noPreguntes);
        expect(result.outcome, AlertToggleOutcome.rejected);
        expect(result.message, contains('2 avisos activos'));
      });
    });

    test('la ruta a 1,5 km se arma a 2 km pero no a 1 km', () async {
      for (final (metros, esperado) in [
        (1000, AlertToggleOutcome.rejected),
        (2000, AlertToggleOutcome.activated),
      ]) {
        final container = await listo(routeKm: 1.5);
        final result = await container
            .read(alertToggleProvider)
            .toggle('A-1', elegirDistancia: _unaVez(metros));
        expect(result.outcome, esperado, reason: 'aviso a $metros m');
        if (esperado == AlertToggleOutcome.rejected) {
          expect(result.message, contains('Elige una distancia mayor'));
          expect(container.read(activeAlertsProvider), isEmpty);
        }
      }
    });

    // Una guardada por debajo de lo más cerca que pasa la ruta no sonaría
    // nunca: en vez de decir que no, la rueda ofrece desde ahí (dueño,
    // 2026-10-07: «se guarda sabiendo que eso nunca va a sonar»).
    test('con la guardada corta y la ruta a 1,45 km, la rueda arranca en 1,5',
        () async {
      final container =
          await listo(routeKm: 1.45, guardado: {'distancia_aviso_m': 1000});
      int? piso;
      final result = await container.read(alertToggleProvider).toggle('A-1',
          elegirDistancia: (desde, _) async {
        piso = desde;
        return (metros: 1500, guardar: false);
      });
      expect(piso, 1500);
      expect(result.outcome, AlertToggleOutcome.activated);
      expect(container.read(proximityAlertsProvider.notifier).radioDe('A-1'),
          1500);
      expect(container.read(distanciaAvisoProvider), 1000);
    });

    test('con la ruta pegada la rueda va entera por abajo', () async {
      final container = await listo();
      int? piso = -1;
      await container.read(alertToggleProvider).toggle('A-1',
          elegirDistancia: (desde, _) async {
        piso = desde;
        return null;
      });
      expect(piso, isNull);
    });

    // La ruta pasa a 1,5 km y el bus va a 1,6: lo que el bus deja (hasta
    // 1,3 km) no alcanza la ruta. Ninguna distancia sirve: se dice sin rueda.
    test('si lo que deja el bus no alcanza la ruta, lo dice sin rueda',
        () async {
      final container = await listo(
        routeKm: 1.5,
        buses: [busLejos.copyWith(lat: 6.2585)], // ≈ 1,6 km
      );
      final result = await container
          .read(alertToggleProvider)
          .toggle('A-1', elegirDistancia: _noPreguntes);
      expect(result.outcome, AlertToggleOutcome.rejected);
      expect(
          result.message,
          'El bus A-1 ya va por lo más cerca que te pasa su ruta; no se '
          'puede activar el aviso');
      expect(container.read(activeAlertsProvider), isEmpty);
    });
  });

  // Se mide por la ruta, no en línea recta (A2, 2026-10-08): una U de
  // 1500 m de ida, 400 m de lado y 1500 m de vuelta, en metros alrededor
  // del usuario. Las cifras salen del dibujo, a mano.
  group('por la ruta', () {
    GeoPoint m(double x, double y) => GeoPoint(
          lat: _userLat + y / 111320,
          lon: _userLon + x / (111320 * math.cos(_userLat * math.pi / 180)),
        );
    final u = [m(0, 0), m(1500, 0), m(1500, 400), m(0, 400)];
    BusPosition bus(double x, double y, double rumbo) {
      final p = m(x, y);
      return busLejos.copyWith(lat: p.lat, lon: p.lon, heading: rumbo);
    }

    Future<ProviderContainer> montar(BusPosition b, GeoPoint espera,
        {List<GeoPoint>? ruta}) async {
      SharedPreferences.setMockInitialValues({});
      final c =
          _container(buses: [b], permissionGranted: true, ruta: ruta ?? u);
      (c.read(userLocationProvider.notifier) as _TestUserLocation)
          .set(UserLocationState(
        mode: UserLocationMode.manual,
        lat: espera.lat,
        lon: espera.lon,
        updatedAt: DateTime.now(),
      ));
      c.read(selectedRouteProvider.notifier).select(route());
      final subs = [
        c.listen(busPositionsSourceProvider('R1'), (_, __) {}),
        c.listen(seguidorRutaProvider('R1'), (_, __) {}),
      ];
      for (final s in subs) {
        addTearDown(s.close);
      }
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      return c;
    }

    test('a 400 m en recta y 3,4 km por la ruta, la rueda va entera', () async {
      final c = await montar(bus(0, 0, 90), m(0, 400));
      int? hasta = -1;
      final result = await c.read(alertToggleProvider).toggle('A-1',
          elegirDistancia: (_, h) async {
        hasta = h;
        return (metros: 3000, guardar: false);
      });

      expect(hasta, isNull);
      expect(result.outcome, AlertToggleOutcome.activated);
    });

    test('un bus que ya pasó el punto no se cuenta hasta su vuelta siguiente',
        () async {
      // La U cerrada en una vuelta de 3800 m. El bus va en el 2650 y el
      // punto está en el 1700: 950 hacia atrás, no 2850 hasta la vuelta
      // siguiente (dueño, 2026-10-19). La rueda deja 200 m con él: hasta
      // 700.
      final c =
          await montar(bus(750, 400, 270), m(1500, 200), ruta: [...u, m(0, 0)]);
      int? hasta;
      final result = await c.read(alertToggleProvider).toggle('A-1',
          elegirDistancia: (_, h) async {
        hasta = h;
        return (metros: 500, guardar: false);
      });

      expect(hasta, 700);
      expect(result.outcome, AlertToggleOutcome.activated);
    });
  });
}
