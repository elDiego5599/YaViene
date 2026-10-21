import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

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
              String? companyId,
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

  // Con la app abierta el aviso también se siente: dos toques, como el
  // de una alarma que suena (dueño, 2026-10-19). Si no se vio, nada.
  for (final mostrado in [true, false]) {
    test('el aviso que suena se siente en la mano (mostrado: $mostrado)',
        () async {
      var sentidos = 0;
      final c = ProviderContainer(overrides: [
        userLocationProvider.overrideWith((ref) => _TestUserLocation()),
        busPositionsSourceProvider.overrideWith(
          (ref, routeId) => Stream.value([busA]),
        ),
        proximityAlertsProvider.overrideWith((ref) => ProximityAlertsNotifier(
              ref,
              notify: (
                      {required String busId,
                      String? routeName,
                      String? routeId,
                      String? companyId,
                      required int distanceMeters}) async =>
                  mostrado,
              sentir: () async => sentidos++,
            )),
      ]);
      addTearDown(c.dispose);
      (c.read(userLocationProvider.notifier) as _TestUserLocation)
          .set(userHere);
      final sub = c.listen<AsyncValue<List<BusPosition>>>(
        busPositionsSourceProvider('R1'),
        (_, __) {},
      );
      addTearDown(sub.close);
      await Future<void>.delayed(Duration.zero);
      c.read(selectedRouteProvider.notifier).select(route());
      c.read(activeAlertsProvider.notifier).toggleAlert('A-1');

      await c.read(proximityAlertsProvider.notifier).check();

      expect(sentidos, mostrado ? 1 : 0);
    });
  }

  // Con `onlyAlertOnce`, una notificación vieja del bus en la bandeja
  // callaría la nueva: armar el aviso otra vez la retira. Re-armar lo que ya
  // estaba (abrir la app, «Deshacer») no toca la bandeja.
  test('armar un aviso retira la notificación vieja de ese bus', () async {
    final retirados = <String>[];
    final c = ProviderContainer(overrides: [
      userLocationProvider.overrideWith((ref) => _TestUserLocation()),
      proximityAlertsProvider.overrideWith((ref) => ProximityAlertsNotifier(
            ref,
            notify: (
                    {required String busId,
                    String? routeName,
                    String? routeId,
                    String? companyId,
                    required int distanceMeters}) async =>
                true,
            retirar: (busId) async => retirados.add(busId),
          )),
      busPositionsSourceProvider.overrideWith(
        (ref, routeId) => const Stream<List<BusPosition>>.empty(),
      ),
    ]);
    addTearDown(c.dispose);
    final avisos = c.read(proximityAlertsProvider.notifier);

    avisos.armAlert('A-1', 'R1');
    expect(retirados, ['A-1']);

    avisos.rearmar(AlertHistoryEntry(
      busId: 'B-2',
      routeId: 'R1',
      createdAt: DateTime.now(),
    ));
    expect(retirados, ['A-1']);
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
              String? companyId,
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
              String? companyId,
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
              String? companyId,
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

  // Riesgo: rearmar en cuanto el bus sale del radio de 1000 m. El GPS del bus
  // salta unos metros y un bus que ronda el borde sonaría una y otra vez. Ya
  // avisado, se rearma solo pasados 1500 m: a 1200 m y de vuelta, silencio;
  // a 1600 m y de vuelta, suena otra vez.
  test('ya avisado, solo vuelve a sonar si el bus se alejó más de 1500 m',
      () async {
    BusPosition busA(double lat) => BusPosition(
          busId: 'A-1',
          routeId: 'R1',
          lat: lat,
          lon: -75.5812,
          heading: 0,
          speedKmh: 20,
          timestamp: DateTime.now(),
          isGhostBus: false,
        );
    // Desde el usuario en 6.2442: 0,0072° ≈ 800 m, 0,0108° ≈ 1200 m y
    // 0,0144° ≈ 1600 m al norte.
    final a800 = busA(6.2514), a1200 = busA(6.2550), a1600 = busA(6.2586);
    final posController = StreamController<List<BusPosition>>.broadcast();
    final localFired = <String>[];
    final c = ProviderContainer(overrides: [
      userLocationProvider
          .overrideWith((ref) => _TestUserLocation()..set(userHere)),
      busPositionsSourceProvider
          .overrideWith((ref, routeId) => posController.stream),
      proximityAlertsProvider.overrideWith((ref) => ProximityAlertsNotifier(
            ref,
            notify: (
                {required String busId,
                String? routeName,
                String? routeId,
                String? companyId,
                required int distanceMeters}) async {
              localFired.add(busId);
              return true;
            },
          )),
    ]);
    addTearDown(c.dispose);
    addTearDown(posController.close);
    final keepAlive = c.listen<AsyncValue<List<BusPosition>>>(
      busPositionsSourceProvider('R1'),
      (_, __) {},
    );
    addTearDown(keepAlive.close);
    c.read(selectedRouteProvider.notifier).select(route());
    final notifier = c.read(proximityAlertsProvider.notifier);
    Future<void> busEn(BusPosition p) async {
      posController.add([p]);
      await Future<void>.delayed(Duration.zero);
      await notifier.check();
    }

    c.read(activeAlertsProvider.notifier).toggleAlert('A-1');
    await busEn(a1200);
    expect(localFired, isEmpty, reason: 'a 1200 m todavía no está cerca');
    await busEn(a800);
    expect(localFired, hasLength(1));

    // Activo otra vez sin re-armar: la marca de «ya avisó» sigue puesta.
    c.read(activeAlertsProvider.notifier).toggleAlert('A-1');
    await busEn(a1200);
    await busEn(a800);
    expect(localFired, hasLength(1),
        reason: 'a 1200 m no se rearma: el borde no suena dos veces');

    await busEn(a1600);
    await busEn(a800);
    expect(localFired, hasLength(2),
        reason: 'pasados 1500 m se rearma y vuelve a sonar');
  });

  // La distancia del aviso la pone la persona, de 500 m a 3 km (dueño,
  // 2026-10-06). Cada aviso mide con la suya.
  group('distancia propia de cada aviso', () {
    BusPosition busEnLat(double lat) => BusPosition(
          busId: 'A-1',
          routeId: 'R1',
          lat: lat,
          lon: -75.5812,
          heading: 0,
          speedKmh: 20,
          timestamp: DateTime.now(),
          isGhostBus: false,
        );
    // Al norte del usuario (6.2442), a 111,2 km por grado: 0,0036° ≈ 400 m,
    // 0,0072° ≈ 800 m, 0,0144° ≈ 1600 m y 0,0234° ≈ 2600 m.
    final a400 = busEnLat(6.2478),
        a800 = busEnLat(6.2514),
        a1600 = busEnLat(6.2586),
        a2600 = busEnLat(6.2676);

    late StreamController<List<BusPosition>> posiciones;
    late List<int> sonados;
    late ProviderContainer c;
    late ProximityAlertsNotifier avisos;

    setUp(() {
      posiciones = StreamController<List<BusPosition>>.broadcast();
      sonados = [];
      c = ProviderContainer(overrides: [
        userLocationProvider
            .overrideWith((ref) => _TestUserLocation()..set(userHere)),
        busPositionsSourceProvider
            .overrideWith((ref, routeId) => posiciones.stream),
        proximityAlertsProvider.overrideWith((ref) => ProximityAlertsNotifier(
              ref,
              notify: (
                  {required String busId,
                  String? routeName,
                  String? routeId,
                  String? companyId,
                  required int distanceMeters}) async {
                sonados.add(distanceMeters);
                return true;
              },
            )),
      ]);
      final keepAlive = c.listen<AsyncValue<List<BusPosition>>>(
        busPositionsSourceProvider('R1'),
        (_, __) {},
      );
      addTearDown(() {
        keepAlive.close();
        c.dispose();
        return posiciones.close();
      });
      avisos = c.read(proximityAlertsProvider.notifier);
    });

    Future<void> busEn(BusPosition p) async {
      posiciones.add([p]);
      await Future<void>.delayed(Duration.zero);
      await avisos.check();
    }

    void armar(int radioM) {
      c.read(activeAlertsProvider.notifier).activateAlert('A-1');
      avisos.armAlert('A-1', 'R1', radioM: radioM);
    }

    test('a 500 m no suena con el bus a 800 m; a 400 m sí', () async {
      armar(500);
      await busEn(a800);
      expect(sonados, isEmpty);
      await busEn(a400);
      expect(sonados, hasLength(1));
    });

    test('suena cuando la distancia del bus es exactamente el radio', () async {
      armar(0);
      await busEn(busEnLat(6.2442));

      expect(sonados, [0]);
    });

    test('a 2 km suena con el bus a 1,6 km', () async {
      armar(2000);
      await busEn(a1600);
      expect(sonados, hasLength(1));
      expect(avisos.radioDe('A-1'), isNull,
          reason: 'el que sonó ya no está armado');
    });

    test('re-armar desde el historial conserva la distancia', () async {
      expect(
        avisos.rearmar(AlertHistoryEntry(
          busId: 'A-1',
          routeId: 'R1',
          createdAt: DateTime.now(),
          radioM: 500,
        )),
        isTrue,
      );
      expect(avisos.radioDe('A-1'), 500);
      await busEn(a800);
      expect(sonados, isEmpty);
    });

    test('cambiar la distancia del bus seguido mide con la nueva', () async {
      armar(500);
      expect(
          c.read(activeAlertsProvider.notifier).activateAlert('B-2'), isFalse);
      await busEn(a800);
      expect(sonados, isEmpty);

      avisos.cambiarRadio('A-1', 1000);

      expect(avisos.radioDe('A-1'), 1000);
      expect(avisos.radioDe('B-2'), isNull);
      final historial = {
        for (final e in c.read(alertHistoryProvider)) e.busId: e.radioM
      };
      expect(historial, {'A-1': 1000});
      await busEn(a800);
      expect(sonados, hasLength(1));
    });

    // El rearme era 1500 m fijo, pensado para el kilómetro de antes. Con un
    // aviso a 2 km, un bus ya avisado a 1,6 km quedaba «lejos» (rearmado) y
    // el barrido siguiente lo volvía a dar por cerca: sonaba dos veces sin
    // que el bus se moviera. El rearme va 500 m más allá de su distancia.
    test('ya avisado a 2 km, no vuelve a sonar hasta pasar los 2,5 km',
        () async {
      armar(2000);
      await busEn(a1600);
      expect(sonados, hasLength(1));

      // Activo otra vez por el camino viejo, sin re-armar: la marca de «ya
      // avisó» sigue puesta y la distancia viene del historial.
      c.read(alertHistoryProvider.notifier).upsert('A-1',
          routeId: 'R1',
          refLat: userHere.lat,
          refLon: userHere.lon,
          radioM: 2000);
      c.read(activeAlertsProvider.notifier).activateAlert('A-1');
      await busEn(a1600);
      await busEn(a1600);
      expect(sonados, hasLength(1),
          reason: 'a 1,6 km sigue dentro de los 2 km: no se rearma');

      await busEn(a2600);
      await busEn(a1600);
      expect(sonados, hasLength(2),
          reason: 'pasados 2,5 km se rearma y vuelve a sonar');
    });

    test('cambiar la distancia de un bus sin aviso no hace nada', () {
      avisos.cambiarRadio('A-1', 2000);
      expect(avisos.radioDe('A-1'), isNull);
      expect(c.read(alertHistoryProvider), isEmpty);
    });
  });

  // Un bus sin señal se pinta en su último punto conocido, que puede ser de
  // hace horas. Ese punto no dice que el bus esté cerca: no suena.
  test('un bus sin señal, aunque su último punto esté encima, no suena',
      () async {
    final fantasma = busA.copyWith(isGhostBus: true);
    final localFired = <String>[];
    final c = ProviderContainer(overrides: [
      userLocationProvider
          .overrideWith((ref) => _TestUserLocation()..set(userHere)),
      busPositionsSourceProvider
          .overrideWith((ref, routeId) => Stream.value([fantasma])),
      proximityAlertsProvider.overrideWith((ref) => ProximityAlertsNotifier(
            ref,
            notify: (
                {required String busId,
                String? routeName,
                String? routeId,
                String? companyId,
                required int distanceMeters}) async {
              localFired.add(busId);
              return true;
            },
          )),
    ]);
    addTearDown(c.dispose);
    final keepAlive = c.listen<AsyncValue<List<BusPosition>>>(
      busPositionsSourceProvider('R1'),
      (_, __) {},
    );
    addTearDown(keepAlive.close);
    await Future<void>.delayed(Duration.zero);
    expect(c.read(busPositionsSourceProvider('R1')).value?.single.isGhostBus,
        isTrue);

    c.read(selectedRouteProvider.notifier).select(route());
    c.read(activeAlertsProvider.notifier).toggleAlert('A-1');
    await c.read(proximityAlertsProvider.notifier).check();

    expect(localFired, isEmpty);
    expect(c.read(activeAlertsProvider), {'A-1'},
        reason: 'el aviso sigue esperando a que el bus vuelva a reportar');
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

  // Lo que vio el dueño en el teléfono (2026-09-28): con GPS se arma el
  // aviso y después se arrastra el pin a otro sitio. El aviso armado con GPS
  // no tenía ancla (mide en vivo) y «en vivo» pasaba a ser el pin: el aviso
  // se mudaba con él. Al pasar a pin, se queda donde estaba el GPS.
  test('arrastrar el pin NO mueve un aviso armado con GPS', () async {
    final notifier =
        container.read(userLocationProvider.notifier) as _TestUserLocation;
    container.read(selectedRouteProvider.notifier).select(route());
    container.read(activeAlertsProvider.notifier).toggleAlert('A-1');
    final alerts = container.read(proximityAlertsProvider.notifier);
    alerts.armAlert('A-1', 'R1');
    expect(alerts.anchorFor('A-1'), isNull, reason: 'con GPS mide en vivo');

    // Pin a ~12 km del bus: si el aviso midiera desde ahí no sonaría.
    notifier.set(UserLocationState(
      mode: UserLocationMode.manual,
      lat: 6.35,
      lon: -75.55,
      updatedAt: DateTime.now(),
    ));

    expect(alerts.anchorFor('A-1'), (6.2442, -75.5812));
    // Y queda escrito: al reabrir la app sigue en el mismo punto.
    final entrada = container.read(alertHistoryProvider).single;
    expect((entrada.refLat, entrada.refLon), (6.2442, -75.5812));

    await alerts.check();
    expect(fired, hasLength(1), reason: 'mide desde donde estaba el GPS');
  });

  // Con «Quitar» (dueño, 2026-10-07) el GPS se va y el mapa queda sin punto
  // hasta que el usuario toca otro: el aviso armado con GPS no puede mudarse
  // a ese punto nuevo. Se queda donde estaba el GPS al quitarlo.
  test('quitar el pin del GPS y tocar otro NO mueve el aviso', () async {
    final notifier =
        container.read(userLocationProvider.notifier) as _TestUserLocation;
    container.read(selectedRouteProvider.notifier).select(route());
    container.read(activeAlertsProvider.notifier).toggleAlert('A-1');
    final alerts = container.read(proximityAlertsProvider.notifier);
    alerts.armAlert('A-1', 'R1');

    notifier.set(const UserLocationState(mode: UserLocationMode.sinPunto));
    notifier.set(UserLocationState(
      mode: UserLocationMode.manual,
      lat: 6.35,
      lon: -75.55,
      updatedAt: DateTime.now(),
    ));

    expect(alerts.anchorFor('A-1'), (6.2442, -75.5812));
    await alerts.check();
    expect(fired, hasLength(1), reason: 'mide desde donde estaba el GPS');
  });

  test('el GPS que se mueve sigue arrastrando el aviso armado con GPS',
      () async {
    final notifier =
        container.read(userLocationProvider.notifier) as _TestUserLocation;
    container.read(selectedRouteProvider.notifier).select(route());
    container.read(activeAlertsProvider.notifier).toggleAlert('A-1');
    final alerts = container.read(proximityAlertsProvider.notifier);
    alerts.armAlert('A-1', 'R1');

    // Con GPS, el punto de espera es la persona: si camina, el aviso va con
    // ella. Solo el pin manual lo fija.
    notifier.set(UserLocationState(
      mode: UserLocationMode.gps,
      lat: 6.35,
      lon: -75.55,
      updatedAt: DateTime.now(),
    ));

    expect(alerts.anchorFor('A-1'), isNull);
    await alerts.check();
    expect(fired, isEmpty);
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
              String? companyId,
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
              String? companyId,
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

  test('el bus seguido conserva el pin con el que se armó', () async {
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

    // Al mover el pin y elegir otro bus, no se cambia el seguimiento activo.
    notifier.set(UserLocationState(
      mode: UserLocationMode.manual,
      lat: 6.35,
      lon: -75.55,
      updatedAt: DateTime.now(),
    ));
    expect(
      container.read(activeAlertsProvider.notifier).activateAlert('A-2'),
      isFalse,
    );

    final alerts = container.read(proximityAlertsProvider.notifier);
    expect(alerts.anchorFor('A-1'), (6.2442, -75.5812));
    expect(alerts.anchorFor('A-2'), isNull);
  });

  // Un bus que se va a descansar al patio se oculta del mapa y nadie sabe
  // cuándo vuelve. El aviso no se perdía: se quedaba armado sin fecha y
  // podía sonar al día siguiente, cuando la persona ya no está esperando.
  group('un aviso que no llega a sonar vence', () {
    ProviderContainer conReloj(DateTime Function() ahora) {
      final c = ProviderContainer(overrides: [
        userLocationProvider.overrideWith((ref) => _TestUserLocation()),
        // El bus no está en la calle: oculto en el patio.
        busPositionsSourceProvider.overrideWith(
          (ref, routeId) => Stream.value(const <BusPosition>[]),
        ),
        proximityAlertsProvider.overrideWith((ref) {
          return ProximityAlertsNotifier(
            ref,
            ahora: ahora,
            notify: (
                {required String busId,
                String? routeName,
                String? routeId,
                String? companyId,
                required int distanceMeters}) async {
              fired.add((busId: busId, distanceMeters: distanceMeters));
              return true;
            },
          );
        }),
      ]);
      addTearDown(c.dispose);
      (c.read(userLocationProvider.notifier) as _TestUserLocation)
          .set(userHere);
      return c;
    }

    test('pasada su vida, sale de los activos y del historial', () async {
      var ahora = DateTime.now();
      final c = conReloj(() => ahora);
      c.read(selectedRouteProvider.notifier).select(route());
      c.read(activeAlertsProvider.notifier).toggleAlert('A-1');
      c.read(proximityAlertsProvider.notifier).armAlert('A-1', 'R1');

      ahora = ahora.add(vidaDeUnAviso - const Duration(minutes: 1));
      await c.read(proximityAlertsProvider.notifier).check();
      expect(c.read(activeAlertsProvider), {'A-1'},
          reason: 'antes de vencer el aviso sigue esperando');

      ahora = ahora.add(const Duration(minutes: 2));
      await c.read(proximityAlertsProvider.notifier).check();
      expect(c.read(activeAlertsProvider), isEmpty);
      expect(c.read(alertHistoryProvider), isEmpty);
      expect(fired, isEmpty);
    });

    test('al reabrir la app no se re-arma uno vencido', () async {
      final viejo =
          DateTime.now().subtract(vidaDeUnAviso + const Duration(minutes: 5));
      SharedPreferences.setMockInitialValues({
        'alert_history': jsonEncode([
          {
            'busId': 'A-1',
            'routeId': 'R1',
            'routeName': 'Ruta 1',
            'createdAt': viejo.toIso8601String(),
            'sentAt': null,
          },
        ]),
      });
      final c = conReloj(DateTime.now);

      await c.read(proximityAlertsProvider.notifier).restore();

      expect(c.read(activeAlertsProvider), isEmpty);
      expect(c.read(alertHistoryProvider), isEmpty);
    });
  });

  // Se mide por la ruta, no en línea recta (A2, 2026-10-08): una U de
  // 1500 m de ida, 400 m de lado y 1500 m de vuelta. Las cifras salen del
  // dibujo, a mano.
  group('por la ruta', () {
    GeoPoint m(double x, double y) => GeoPoint(
          lat: 6.2442 + y / 111320,
          lon: -75.5812 + x / (111320 * math.cos(6.2442 * math.pi / 180)),
        );
    BusPosition bus(double x, double y, double rumbo) {
      final p = m(x, y);
      return busA.copyWith(lat: p.lat, lon: p.lon, heading: rumbo);
    }

    Future<List<({String busId, int distanceMeters})>> barrer(
        BusPosition b, GeoPoint espera) async {
      final sonaron = <({String busId, int distanceMeters})>[];
      final c = ProviderContainer(overrides: [
        userLocationProvider.overrideWith((ref) => _TestUserLocation()
          ..set(UserLocationState(
            mode: UserLocationMode.manual,
            lat: espera.lat,
            lon: espera.lon,
            updatedAt: DateTime.now(),
          ))),
        busPositionsSourceProvider
            .overrideWith((ref, routeId) => Stream.value([b])),
        routeTrajectoryProvider.overrideWith((ref, routeId) => RouteTrajectory(
              routeId: routeId,
              routeName: 'Ruta 1',
              points: [m(0, 0), m(1500, 0), m(1500, 400), m(0, 400)],
            )),
        proximityAlertsProvider.overrideWith((ref) => ProximityAlertsNotifier(
              ref,
              notify: (
                  {required String busId,
                  String? routeName,
                  String? routeId,
                  String? companyId,
                  required int distanceMeters}) async {
                sonaron.add((busId: busId, distanceMeters: distanceMeters));
                return true;
              },
            )),
      ]);
      addTearDown(c.dispose);
      c.read(selectedRouteProvider.notifier).select(route());
      c.read(activeAlertsProvider.notifier).toggleAlert('A-1');
      c.read(proximityAlertsProvider.notifier).armAlert('A-1', 'R1');
      await Future<void>.delayed(Duration.zero);
      await c.read(proximityAlertsProvider.notifier).check();
      return sonaron;
    }

    test('a 400 m en línea recta pero a 3,4 km por la ruta, no suena',
        () async {
      expect(await barrer(bus(0, 0, 90), m(0, 400)), isEmpty);
    });

    test('suena con la distancia por la ruta, no la recta', () async {
      // Recta: √(500² + 300²) ≈ 583 m. Por la ruta: 300 + 500 = 800 m.
      final sonaron = await barrer(bus(1500, 100, 0), m(1000, 400));
      expect(sonaron.single.distanceMeters, closeTo(800, 10));
    });

    test('un bus que ya dejó atrás el punto suena con lo que lo dejó atrás',
        () async {
      // No se sabe qué sentido espera la persona: mejor que suene de más.
      // Del 2650 al 1700 de la ruta abierta, 950 m, dentro del 1 km (en
      // recta, 776; dueño, 2026-10-19).
      final sonaron = await barrer(bus(750, 400, 270), m(1500, 200));
      expect(sonaron.single.distanceMeters, closeTo(950, 10));
    });
  });
}
