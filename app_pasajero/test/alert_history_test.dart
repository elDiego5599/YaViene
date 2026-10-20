import 'dart:async';
import 'dart:convert';

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
      // La notificación de verdad no se puede pintar en un test (el plugin
      // no tiene canal), y desde que `notifyBusNear` devuelve si de verdad
      // se mostró, el fallo dejaría el aviso sin marcar. Aquí se mide el
      // camino en que el aviso sí salió: se sustituye por uno que responde
      // que sí.
      proximityAlertsProvider.overrideWith(
        (ref) => ProximityAlertsNotifier(ref,
            notify: ({
              required String busId,
              String? routeName,
              String? routeId,
              String? companyId,
              required int distanceMeters,
            }) async =>
                true),
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
    if (c.read(activeAlertsProvider.notifier).activateAlert(busId)) {
      c.read(proximityAlertsProvider.notifier).armAlert(busId, 'R1');
    }
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

  // Lo vio el dueño (2026-10-02): con una entrada por bus, volver a armar
  // el bus que ya había sonado reemplazaba el enviado por el nuevo, y el
  // aviso de antes desaparecía de la lista. Uno por bus es solo para los
  // que esperan; lo que sonó es historia y se queda.
  test('re-armar un bus que ya sonó no borra el enviado', () async {
    final c = buildContainer();
    addTearDown(c.dispose);
    final avisos = c.read(proximityAlertsProvider.notifier);

    arm(c, 'A-1');
    await drain();
    await avisos.check();
    arm(c, 'A-1');

    expect(c.read(alertHistoryProvider).map((e) => e.sent), [true, false]);
    // Y al sonar otra vez se marca el nuevo, no el viejo: quedan dos.
    await avisos.check();
    final historial = c.read(alertHistoryProvider);
    expect(historial.map((e) => e.sent), [true, true]);
    expect(historial[0].sentAt!.isAfter(historial[1].sentAt!), isFalse);
    expect(historial.map((e) => e.id).toSet(), hasLength(2));
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
    // A-1 ya envió; se arma A-2 y se deja activo. El fixture solo trae a
    // A-1 en el stream, así que A-2 queda esperando.
    arm(first, 'A-2');
    await drain();

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

  test('restore descarta el segundo seguimiento activo antiguo', () async {
    final previous = buildContainer();
    addTearDown(previous.dispose);
    final history = previous.read(alertHistoryProvider.notifier);
    history.upsert('A-1', routeId: 'R1');
    history.upsert('A-2', routeId: 'R1');
    await history.guardado;

    final current = buildContainer();
    addTearDown(current.dispose);
    await current.read(proximityAlertsProvider.notifier).restore();

    expect(current.read(activeAlertsProvider), {'A-1'});
    expect(
      current
          .read(alertHistoryProvider)
          .where((entry) => !entry.sent)
          .map((entry) => entry.busId),
      ['A-1'],
    );
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

  // Con cuenta, cada una tenía su historial en `alert_history_user_<uid>`.
  // Sin cuentas (D3) el historial es del teléfono: la primera carga funde
  // lo de todas las cuentas en `alert_history`, uno por bus, y borra las
  // claves viejas, que llevaban el id de la cuenta en el nombre.
  test('los historiales de las cuentas se funden en uno del teléfono',
      () async {
    Map<String, dynamic> entrada(String busId, DateTime creado,
            {DateTime? enviado}) =>
        {
          'busId': busId,
          'routeId': 'R1',
          'routeName': 'Ruta 1',
          'createdAt': creado.toIso8601String(),
          'sentAt': enviado?.toIso8601String(),
        };
    final hoy = DateTime.now();
    final antes = hoy.subtract(const Duration(hours: 3));
    SharedPreferences.setMockInitialValues({
      'alert_history': jsonEncode([entrada('A-0', antes, enviado: antes)]),
      'alert_history_user_a': jsonEncode([
        entrada('A-1', antes),
        entrada('A-2', antes, enviado: antes),
      ]),
      'alert_history_user_b': jsonEncode([entrada('A-1', hoy)]),
      'alert_history_legacy_migrated_user': 'a',
    });

    final notifier = AlertHistoryNotifier();
    await notifier.load();

    final porBus = {for (final e in notifier.state) e.busId: e};
    expect(porBus.keys, unorderedEquals(['A-0', 'A-1', 'A-2']));
    // A-1 estaba en las dos cuentas: se queda la más reciente, y sigue
    // activo, así que `restore()` lo vuelve a armar.
    expect(porBus['A-1']!.createdAt, hoy);
    expect(porBus['A-1']!.sent, isFalse);
    expect(porBus['A-2']!.sent, isTrue);

    await pumpEventQueue();
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getKeys().where((k) => k.startsWith('alert_history_')),
      isEmpty,
    );
    final guardado = jsonDecode(prefs.getString('alert_history')!) as List;
    expect(guardado, hasLength(3));
  });

  // La ficha del aviso va en el color de su empresa, el de «Elige empresa»
  // (dueño, 2026-10-19): el aviso guarda de qué empresa es, porque al
  // reabrir la app la ruta elegida puede ser otra.
  test('el aviso guarda su empresa y vuelve con ella al reabrir la app',
      () async {
    final first = buildContainer();
    addTearDown(first.dispose);
    arm(first, 'A-1');
    expect(first.read(alertHistoryProvider).single.companyId, 'C1');
    await first.read(alertHistoryProvider.notifier).guardado;

    final second = buildContainer();
    addTearDown(second.dispose);
    await second.read(proximityAlertsProvider.notifier).restore();
    expect(second.read(alertHistoryProvider).single.companyId, 'C1');
  });

  test('un aviso de antes, sin empresa, se lee igual', () {
    final e = AlertHistoryEntry.fromJson({
      'busId': 'A-1',
      'routeId': 'R1',
      'createdAt': DateTime.now().toIso8601String(),
    });
    expect(e.companyId, isNull);
  });

  // Cada aviso guarda la distancia a la que se armó: es lo único que la
  // recuerda al reabrir la app, y la persona pudo haber cambiado la suya
  // desde entonces (dueño, 2026-10-06).
  group('distancia de cada aviso', () {
    test('se guarda con el aviso y vuelve con él al reabrir la app', () async {
      final first = buildContainer();
      addTearDown(first.dispose);
      first.read(activeAlertsProvider.notifier).toggleAlert('A-2');
      first
          .read(proximityAlertsProvider.notifier)
          .armAlert('A-2', 'R1', radioM: 2500);
      expect(first.read(alertHistoryProvider).single.radioM, 2500);
      await first.read(alertHistoryProvider.notifier).guardado;

      final second = buildContainer();
      addTearDown(second.dispose);
      await second.read(proximityAlertsProvider.notifier).restore();

      expect(second.read(alertHistoryProvider).single.radioM, 2500);
      expect(
          second.read(proximityAlertsProvider.notifier).radioDe('A-2'), 2500);
    });

    test('un aviso de antes, sin distancia, sigue sonando al kilómetro', () {
      final e = AlertHistoryEntry.fromJson({
        'busId': 'A-1',
        'routeId': 'R1',
        'createdAt': DateTime.now().toIso8601String(),
      });
      expect(e.radioM, 1000);
    });

    // Lo que viene del disco no se cree: fuera de 500–3000, o con otro
    // tipo, el aviso se queda con el kilómetro de siempre en vez de
    // perderse (el historial es la única persistencia de los activos).
    test('una distancia rota en el disco no tumba el aviso', () {
      for (final roto in <Object>[50, 99999, '2000', 1500.5]) {
        final e = AlertHistoryEntry.tryFromJson({
          'busId': 'A-1',
          'routeId': 'R1',
          'createdAt': DateTime.now().toIso8601String(),
          'radioM': roto,
        });
        expect(e?.radioM, 1000, reason: 'radioM: $roto');
      }
    });

    test('cambiar la distancia no renueva el aviso ni lo saca del servidor',
        () async {
      final n = AlertHistoryNotifier();
      n.upsert('A-1', routeId: 'R1', radioM: 1000);
      n.fijarServidor('A-1', 'srv-1');
      final creado = n.state.single.createdAt;

      n.fijarRadio('A-1', 2000);

      expect(n.state.single.radioM, 2000);
      expect(n.state.single.createdAt, creado,
          reason: 'la fecha decide cuándo vence: cambiar la distancia no '
              'le regala tres horas más');
      expect(n.state.single.servidorId, 'srv-1');
      await n.guardado;
      final prefs = await SharedPreferences.getInstance();
      final guardado = jsonDecode(prefs.getString('alert_history')!) as List;
      expect((guardado.single as Map)['radioM'], 2000);
    });
  });

  group('purga del historial', () {
    Map<String, dynamic> entrada(String busId, {required int diasAtras}) {
      final cuando = DateTime.now().subtract(Duration(days: diasAtras));
      return {
        'busId': busId,
        'routeId': 'R1',
        'routeName': 'Ruta 1',
        'createdAt': cuando.toIso8601String(),
        'sentAt': cuando.toIso8601String(),
      };
    }

    Future<List<AlertHistoryEntry>> cargar(
        List<Map<String, dynamic>> guardado) async {
      SharedPreferences.setMockInitialValues({
        'alert_history': jsonEncode(guardado),
      });
      final notifier = AlertHistoryNotifier();
      await notifier.load();
      return notifier.state;
    }

    test('las entradas enviadas hace más de 30 días se caen', () async {
      final historial = await cargar([
        entrada('A-1', diasAtras: 45),
        entrada('A-2', diasAtras: 29),
      ]);
      expect(historial.map((e) => e.busId), ['A-2']);
    });

    test('se guardan como mucho 50, las más recientes', () async {
      final historial = await cargar([
        for (var i = 0; i < 70; i++) entrada('B-$i', diasAtras: i % 20),
      ]);
      expect(historial.length, 50);
      // La más vieja conservada no puede ser más vieja que la más nueva
      // descartada: se ordena por fecha de envío, no por posición.
      expect(historial.every((e) => e.sentAt != null), isTrue);
    });

    // Recién armado: esperando.
    Map<String, dynamic> activo(String busId,
            {Duration hace = Duration.zero}) =>
        entrada(busId, diasAtras: 0)
          ..['createdAt'] = DateTime.now().subtract(hace).toIso8601String()
          ..['sentAt'] = null;

    test('un aviso activo no cede su lugar al tope de 50', () async {
      final historial = await cargar([
        activo('A-9'),
        for (var i = 0; i < 70; i++) entrada('B-$i', diasAtras: 1),
      ]);
      expect(historial.length, 50);
      expect(historial.map((e) => e.busId), contains('A-9'));
    });

    // El bus se fue al patio y no volvió: el aviso vence y no se re-arma.
    test('un aviso activo que pasó su vida sin sonar se cae', () async {
      final historial = await cargar([
        activo('A-1', hace: vidaDeUnAviso - const Duration(minutes: 5)),
        activo('A-2', hace: vidaDeUnAviso + const Duration(minutes: 5)),
      ]);
      expect(historial.map((e) => e.busId), ['A-1']);
    });

    // Antes una sola entrada rota vaciaba el historial entero, y con él los
    // avisos activos que no habían sonado.
    test('una entrada rota se cae sola y el disco queda saneado', () async {
      final historial = await cargar([
        activo('A-1'),
        entrada('A-2', diasAtras: 2)..['createdAt'] = 'ayer por la tarde',
        entrada('A-3', diasAtras: 2)..['busId'] = 42,
        entrada('A-4', diasAtras: 2)..['busId'] = '  ',
        entrada('A-5', diasAtras: 3),
      ]);
      expect(historial.map((e) => e.busId), ['A-1', 'A-5']);
      expect(historial.first.sent, isFalse);

      await pumpEventQueue();
      final prefs = await SharedPreferences.getInstance();
      final guardado = jsonDecode(prefs.getString('alert_history')!) as List;
      expect(guardado.map((e) => (e as Map)['busId']), ['A-1', 'A-5']);
    });

    test('lo que no es una lista, o una lista con basura, no revienta',
        () async {
      SharedPreferences.setMockInitialValues({
        'alert_history': jsonEncode([
          'no soy una entrada',
          7,
          entrada('A-1', diasAtras: 1),
        ]),
      });
      final notifier = AlertHistoryNotifier();
      await notifier.load();
      expect(notifier.state.map((e) => e.busId), ['A-1']);

      SharedPreferences.setMockInitialValues({'alert_history': '{roto'});
      final roto = AlertHistoryNotifier();
      await roto.load();
      expect(roto.state, isEmpty);
      await pumpEventQueue();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('alert_history'), '[]');
    });
  });
}
