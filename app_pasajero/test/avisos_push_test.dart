// Los avisos con la app cerrada (D13 del backend), en Android.
//
// La app avisa sola mientras está viva y le deja el aviso al servidor para
// cuando no lo está: lo arma con POST, late cada 20 s con PUT y lo borra con
// DELETE. Si los latidos paran, el servidor avisa por FCM y la app enseña el
// push como sus propios avisos. Aquí: el cliente HTTP contra los archivos
// del contrato, el vigilante con un servidor falso y el manejador del push
// en el fondo contra el historial en el disco.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/tracking_providers.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/user_location_provider.dart';
import 'package:ya_viene_pasajero/features/notifications/data/avisos_push.dart';
import 'package:ya_viene_pasajero/features/notifications/presentation/providers/alert_history_provider.dart';
import 'package:ya_viene_pasajero/features/notifications/presentation/providers/proximity_alerts_provider.dart';

String _contrato(String nombre) =>
    File('../ya_viene_core/test/fixtures/contrato/$nombre.json')
        .readAsStringSync();

class _TestUserLocation extends UserLocationNotifier {
  void set(UserLocationState state) => this.state = state;
}

typedef _Armado = ({
  String token,
  String busId,
  String routeId,
  double lat,
  double lon,
  Duration vida,
  int radioM,
});

/// El servidor de avisos, en memoria.
class _PushFalso implements AvisosPush {
  String? tokenActual = 'tok-1';
  final armados = <_Armado>[];
  final latidos = <String>[];
  final borrados = <String>[];
  var _siguiente = 0;
  ({String? id, bool apagado})? respuesta;
  Latido latido = Latido.renovado;
  bool borrarFunciona = true;
  Completer<void>? frenoArmar;

  @override
  Future<String?> token() async => tokenActual;

  @override
  Future<({String? id, bool apagado})> armar({
    required String token,
    required String busId,
    required String routeId,
    required double lat,
    required double lon,
    required Duration vida,
    required int radioM,
  }) async {
    armados.add((
      token: token,
      busId: busId,
      routeId: routeId,
      lat: lat,
      lon: lon,
      vida: vida,
      radioM: radioM,
    ));
    await frenoArmar?.future;
    return respuesta ?? (id: 'srv-${++_siguiente}', apagado: false);
  }

  @override
  Future<Latido> latir(
    String id, {
    required String token,
    required double lat,
    required double lon,
  }) async {
    latidos.add(id);
    return latido;
  }

  @override
  Future<bool> borrar(String id) async {
    borrados.add(id);
    return borrarFunciona;
  }
}

void main() {
  group('AvisosPush contra el contrato', () {
    late List<http.Request> pedidos;

    AvisosPush cliente(http.Response Function(http.Request) responder) =>
        AvisosPush(
          backend: () => 'http://servidor',
          cliente: MockClient((r) async {
            pedidos.add(r);
            return responder(r);
          }),
          token: () async => 'tok-1',
        );

    setUp(() => pedidos = []);

    test('armar manda el punto redondeado a ~100 m, la distancia y lee el id',
        () async {
      final push = cliente((_) => http.Response(
            _contrato('rest-aviso-creado'),
            201,
            headers: {'content-type': 'application/json'},
          ));

      final r = await push.armar(
        token: 'tok-1',
        busId: 'BUS-1',
        routeId: 'R-1',
        lat: 10.987654,
        lon: -74.812345,
        vida: const Duration(hours: 2),
        radioM: 2300,
      );

      expect(r.id, '<avisoId>');
      expect(r.apagado, isFalse);
      expect(pedidos.single.method, 'POST');
      expect(pedidos.single.url.toString(), 'http://servidor/api/avisos');
      expect(jsonDecode(pedidos.single.body), {
        'token': 'tok-1',
        'busId': 'BUS-1',
        'routeId': 'R-1',
        'lat': 10.988,
        'lon': -74.812,
        'vidaMs': 7200000,
        'radioM': 2300,
      });
    });

    test('armar: sin push en el servidor queda apagado; otro error, no',
        () async {
      Future<({String? id, bool apagado})> con(int status, String code) =>
          cliente((_) => http.Response(
                jsonEncode({
                  'error': {'code': code, 'message': 'x'},
                }),
                status,
              )).armar(
            token: 't',
            busId: 'B',
            routeId: 'R',
            lat: 0,
            lon: 0,
            vida: const Duration(hours: 1),
            radioM: 1000,
          );

      expect(await con(503, 'PUSH_NO_DISPONIBLE'), (id: null, apagado: true));
      expect(await con(429, 'DEMASIADOS_AVISOS'), (id: null, apagado: false));
      expect(await con(503, 'AVISOS_LLENOS'), (id: null, apagado: false));
      final caido = await cliente((_) => throw const SocketException('x'))
          .armar(
              token: 't',
              busId: 'B',
              routeId: 'R',
              lat: 0,
              lon: 0,
              vida: const Duration(hours: 1),
              radioM: 1000);
      expect(caido, (id: null, apagado: false));
    });

    test('latir traduce lo que contesta el servidor', () async {
      Future<Latido> con(http.Response Function(http.Request) r) =>
          cliente(r).latir('a/1', token: 'tok-1', lat: 1.23456, lon: 2);

      expect(await con((_) => http.Response('', 204)), Latido.renovado);
      expect(
        await con((_) => http.Response(_contrato('rest-aviso-enviado'), 410)),
        Latido.enviado,
      );
      expect(await con((_) => http.Response('', 404)), Latido.noExiste);
      expect(await con((_) => http.Response('', 500)), Latido.fallo);
      expect(await con((_) => throw const SocketException('x')), Latido.fallo);
      expect(pedidos.first.method, 'PUT');
      expect(pedidos.first.url.path, '/api/avisos/a%2F1');
      expect(jsonDecode(pedidos.first.body),
          {'token': 'tok-1', 'lat': 1.235, 'lon': 2.0});
    });

    test('borrar: 204 y 404 cuentan como hecho; lo demás se reintenta',
        () async {
      Future<bool> con(http.Response Function(http.Request) r) =>
          cliente(r).borrar('a1');

      expect(await con((_) => http.Response('', 204)), isTrue);
      expect(await con((_) => http.Response('', 404)), isTrue);
      expect(await con((_) => http.Response('', 500)), isFalse);
      expect(await con((_) => throw const SocketException('x')), isFalse);
      expect(pedidos.first.method, 'DELETE');
    });

    test('sin Firebase (iOS, pruebas) no hay token ni mensajes', () async {
      final push = AvisosPush(backend: () => 'http://servidor');
      expect(await push.token(), isNull);
      expect(await AvisosPush.mensajes.isEmpty, isTrue);
    });
  });

  group('el vigilante de avisos con el servidor', () {
    late ProviderContainer container;
    late _PushFalso push;
    late List<({String busId, String? routeName, int distanceMeters})> fired;
    late bool mostrar;
    late DateTime reloj;

    final busA = BusPosition(
      busId: 'A-1',
      routeId: 'R1',
      // Lejos (más de 1 km): el barrido local no avisa solo.
      lat: 6.30,
      lon: -75.5812,
      heading: 0,
      speedKmh: 20,
      timestamp: DateTime.now(),
      isGhostBus: false,
    );

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      push = _PushFalso();
      fired = [];
      mostrar = true;
      reloj = DateTime.now();
      container = ProviderContainer(overrides: [
        userLocationProvider.overrideWith((ref) => _TestUserLocation()),
        busPositionsSourceProvider.overrideWith(
          (ref, routeId) => Stream.value([busA]),
        ),
        proximityAlertsProvider.overrideWith((ref) {
          return ProximityAlertsNotifier(
            ref,
            push: push,
            ahora: () => reloj,
            notify: (
                {required String busId,
                String? routeName,
                String? routeId,
                required int distanceMeters}) async {
              fired.add((
                busId: busId,
                routeName: routeName,
                distanceMeters: distanceMeters,
              ));
              return mostrar;
            },
          );
        }),
      ]);
      (container.read(userLocationProvider.notifier) as _TestUserLocation)
          .set(UserLocationState(
        mode: UserLocationMode.gps,
        lat: 6.244213,
        lon: -75.581287,
        updatedAt: DateTime.now(),
      ));
      container.read(selectedRouteProvider.notifier).select(
            const RouteInfo(id: 'R1', name: 'Ruta 1', companyId: 'C1'),
          );
    });

    tearDown(() => container.dispose());

    ProximityAlertsNotifier vigilante() =>
        container.read(proximityAlertsProvider.notifier);
    AlertHistoryEntry? activa() => container
        .read(alertHistoryProvider)
        .where((e) => e.busId == 'A-1' && !e.sent)
        .firstOrNull;

    Future<void> armar() async {
      container.read(activeAlertsProvider.notifier).toggleAlert('A-1');
      vigilante().armAlert('A-1', 'R1');
      // Armar ya sincroniza solo; aquí basta con dejarlo terminar.
      await pumpEventQueue();
    }

    Future<void> quitar() async {
      container.read(activeAlertsProvider.notifier).deactivateAlert('A-1');
      vigilante().disarmAlert('A-1');
      container.read(alertHistoryProvider.notifier).remove('A-1');
      await pumpEventQueue();
    }

    test('armar deja el aviso en el servidor con lo que le queda de vida',
        () async {
      await armar();

      final a = push.armados.single;
      expect(a.token, 'tok-1');
      expect((a.busId, a.routeId, a.lat, a.lon),
          ('A-1', 'R1', 6.244213, -75.581287));
      expect(a.vida, lessThanOrEqualTo(vidaDeUnAviso));
      expect(a.vida, greaterThan(vidaDeUnAviso - const Duration(minutes: 1)));
      expect(activa()?.servidorId, 'srv-1');
      // El historial guarda el id: es lo que lee el push en el fondo.
      await container.read(alertHistoryProvider.notifier).guardado;
      final prefs = await SharedPreferences.getInstance();
      expect(
          prefs.getString('alert_history'), contains('"servidorId":"srv-1"'));
    });

    // El servidor mide con la distancia de cada aviso (migración 29): sin
    // ella, con la app cerrada sonaba al kilómetro aunque la persona hubiera
    // pedido 3 km.
    test('el servidor recibe la distancia del aviso', () async {
      container.read(activeAlertsProvider.notifier).toggleAlert('A-1');
      vigilante().armAlert('A-1', 'R1', radioM: 2700);
      await pumpEventQueue();

      expect(push.armados.single.radioM, 2700);
    });

    // Allá la distancia se fija al armar: «Cambiar» borra el aviso del
    // servidor y arma otro con la nueva, sin tocar la vida que le queda.
    test('cambiar la distancia rearma el aviso en el servidor', () async {
      await armar();
      reloj = reloj.add(const Duration(hours: 1));

      vigilante().cambiarRadio('A-1', 1800);
      await pumpEventQueue();

      expect(push.borrados, ['srv-1']);
      expect(push.armados.map((a) => a.radioM), [1000, 1800]);
      // Lo que le queda (unas 2 h), no tres horas nuevas. El historial
      // fecha con el reloj de verdad y el vigilante con el de la prueba:
      // un minuto de holgura cubre esa diferencia.
      expect(push.armados.last.vida,
          lessThan(vidaDeUnAviso - const Duration(minutes: 59)));
      expect(activa()?.servidorId, 'srv-2');
      expect(activa()?.radioM, 1800);
    });

    test('cambiada mientras el servidor armaba: lo de antes se borra',
        () async {
      push.frenoArmar = Completer<void>();
      container.read(activeAlertsProvider.notifier).toggleAlert('A-1');
      vigilante().armAlert('A-1', 'R1', radioM: 1000);
      await pumpEventQueue();
      expect(push.armados.single.radioM, 1000);

      vigilante().cambiarRadio('A-1', 2500);
      push.frenoArmar!.complete();
      push.frenoArmar = null;
      await vigilante().sincronizarPush();
      await pumpEventQueue();

      expect(push.borrados, ['srv-1'],
          reason: 'el armado con 1 km quedó sin dueño');
      expect(push.armados.map((a) => a.radioM), [1000, 2500]);
      expect(activa()?.servidorId, 'srv-2');
    });

    test('con el aviso ya armado, cada vuelta late en vez de armar', () async {
      await armar();
      await vigilante().sincronizarPush();
      await vigilante().sincronizarPush();

      expect(push.armados, hasLength(1));
      expect(push.latidos, ['srv-1', 'srv-1']);
    });

    test('sin token (iOS) no se arma nada', () async {
      push.tokenActual = null;
      await armar();
      expect(push.armados, isEmpty);
      expect(activa()?.servidorId, isNull);
    });

    test('desarmar lo borra del servidor y reintenta si no hay red', () async {
      await armar();
      push.borrarFunciona = false;
      await quitar();
      expect(push.borrados, ['srv-1']);

      push.borrarFunciona = true;
      await vigilante().sincronizarPush();
      expect(push.borrados, ['srv-1', 'srv-1']);
      await vigilante().sincronizarPush();
      expect(push.borrados, hasLength(2));
    });

    test('desarmado mientras el servidor armaba: lo armado se borra', () async {
      push.frenoArmar = Completer<void>();
      container.read(activeAlertsProvider.notifier).toggleAlert('A-1');
      vigilante().armAlert('A-1', 'R1');
      final sync = vigilante().sincronizarPush();
      await pumpEventQueue();
      container.read(activeAlertsProvider.notifier).deactivateAlert('A-1');
      vigilante().disarmAlert('A-1');
      container.read(alertHistoryProvider.notifier).remove('A-1');
      push.frenoArmar!.complete();
      await sync;

      expect(push.borrados, ['srv-1']);
    });

    test('el servidor perdió el aviso (404): se vuelve a armar', () async {
      await armar();
      push.latido = Latido.noExiste;
      await vigilante().sincronizarPush();

      expect(push.armados, hasLength(2));
      expect(activa()?.servidorId, 'srv-2');
    });

    test('el servidor dice que ya avisó (410) y el push llegó: queda sonado',
        () async {
      await armar();
      await container.read(alertHistoryProvider.notifier).guardado;
      // El proceso de fondo atendió el push y lo marcó en el disco.
      await atenderPushEnFondo(
        {
          'tipo': 'bus_cerca',
          'avisoId': 'srv-1',
          'busId': 'A-1',
          'routeId': 'R1',
          'distancia': '640',
        },
        notify: (
                {required String busId,
                String? routeName,
                String? routeId,
                required int distanceMeters}) async =>
            true,
      );
      push.latido = Latido.enviado;
      await vigilante().sincronizarPush();

      expect(activa(), isNull);
      expect(container.read(alertHistoryProvider).single.sent, isTrue);
      expect(container.read(activeAlertsProvider), isEmpty);
      expect(vigilante().state, contains('A-1'));
      expect(push.armados, hasLength(1));
      expect(fired, isEmpty, reason: 'la app no avisa otra vez');
    });

    test('410 sin que nadie lo viera: el aviso sigue y se arma otra vez',
        () async {
      await armar();
      push.latido = Latido.enviado;
      await vigilante().sincronizarPush();

      expect(container.read(activeAlertsProvider), {'A-1'});
      expect(push.armados, hasLength(2));
      expect(activa()?.servidorId, 'srv-2');
    });

    test('servidor sin push: diez minutos sin preguntar', () async {
      push.respuesta = (id: null, apagado: true);
      await armar();
      expect(push.armados, hasLength(1));

      reloj = reloj.add(const Duration(minutes: 9));
      await vigilante().sincronizarPush();
      expect(push.armados, hasLength(1));

      push.respuesta = null;
      reloj = reloj.add(const Duration(minutes: 2));
      await vigilante().sincronizarPush();
      expect(push.armados, hasLength(2));
      expect(activa()?.servidorId, 'srv-1');
    });

    test('un aviso vencido no se arma en el servidor', () async {
      push.tokenActual = null;
      await armar();
      push.tokenActual = 'tok-1';
      reloj = reloj.add(vidaDeUnAviso + const Duration(minutes: 1));
      await vigilante().sincronizarPush();
      expect(push.armados, isEmpty);
    });

    test('re-armar al reabrir la app late con el id guardado', () async {
      await armar();
      final entrada = activa()!;
      vigilante().clear();
      container.read(activeAlertsProvider.notifier).clear();

      expect(vigilante().rearmar(entrada), isTrue);
      await pumpEventQueue();

      expect(push.armados, hasLength(1));
      expect(push.latidos, ['srv-1']);
    });

    test('un push en primer plano suena como los avisos de la app', () async {
      await armar();
      await vigilante().alPush({
        'tipo': 'bus_cerca',
        'avisoId': 'srv-1',
        'busId': 'A-1',
        'routeId': 'R1',
        'distancia': '640',
      });

      expect(fired.single,
          (busId: 'A-1', routeName: 'Ruta 1', distanceMeters: 640));
      expect(container.read(activeAlertsProvider), isEmpty);
      expect(container.read(alertHistoryProvider).single.sent, isTrue);
      expect(push.borrados, ['srv-1']);
    });

    test('un push de otro aviso (viejo o retirado) no suena', () async {
      await armar();
      await vigilante().alPush({
        'tipo': 'bus_cerca',
        'avisoId': 'otro',
        'busId': 'A-1',
        'distancia': '640',
      });
      await vigilante().alPush({'tipo': 'otra_cosa', 'busId': 'A-1'});

      expect(fired, isEmpty);
      expect(container.read(activeAlertsProvider), {'A-1'});
    });

    test('un push que no se pudo enseñar deja el aviso armado', () async {
      await armar();
      mostrar = false;
      await vigilante().alPush({
        'tipo': 'bus_cerca',
        'avisoId': 'srv-1',
        'busId': 'A-1',
        'distancia': '640',
      });
      await vigilante().sincronizarPush();

      expect(container.read(activeAlertsProvider), {'A-1'});
      expect(push.armados, hasLength(2));
    });

    test('al volver al frente, lo que sonó en el fondo queda sonado', () async {
      await armar();
      await container.read(alertHistoryProvider.notifier).guardado;
      await atenderPushEnFondo(
        {
          'tipo': 'bus_cerca',
          'avisoId': 'srv-1',
          'busId': 'A-1',
          'distancia': '640',
        },
        notify: (
                {required String busId,
                String? routeName,
                String? routeId,
                required int distanceMeters}) async =>
            true,
      );

      await vigilante().alVolver();

      expect(container.read(activeAlertsProvider), isEmpty);
      expect(container.read(alertHistoryProvider).single.sent, isTrue);
      expect(push.borrados, ['srv-1']);
    });
  });

  group('el push en el fondo', () {
    late List<({String busId, String? routeName, int distanceMeters})> fired;
    late bool mostrar;

    Future<bool> notify(
        {required String busId,
        String? routeName,
        String? routeId,
        required int distanceMeters}) async {
      fired.add((
        busId: busId,
        routeName: routeName,
        distanceMeters: distanceMeters,
      ));
      return mostrar;
    }

    Future<List<dynamic>> historial() async {
      final prefs = await SharedPreferences.getInstance();
      return jsonDecode(prefs.getString('alert_history')!) as List<dynamic>;
    }

    setUp(() {
      fired = [];
      mostrar = true;
      SharedPreferences.setMockInitialValues({
        'alert_history': jsonEncode([
          AlertHistoryEntry(
            busId: 'BUS-ABC123',
            routeId: 'R-101',
            routeName: 'Calle 72',
            createdAt: DateTime.now(),
            servidorId: '<avisoId>',
          ).toJson(),
        ]),
      });
    });

    Map<String, dynamic> datosDelContrato() =>
        (jsonDecode(_contrato('push-bus-cerca'))
            as Map<String, dynamic>)['data'] as Map<String, dynamic>;

    test('el push del contrato se enseña y queda enviado en el disco',
        () async {
      await atenderPushEnFondo(datosDelContrato(), notify: notify);

      expect(fired.single, (
        busId: 'BUS-ABC123',
        routeName: 'Calle 72',
        distanceMeters: 300,
      ));
      expect((await historial()).single['sentAt'], isNotNull);
    });

    test('si no se pudo enseñar, el aviso sigue esperando', () async {
      mostrar = false;
      await atenderPushEnFondo(datosDelContrato(), notify: notify);

      expect(fired, hasLength(1));
      expect((await historial()).single['sentAt'], isNull);
    });

    test('un push de un aviso que ya no está no se enseña', () async {
      await atenderPushEnFondo(
        {...datosDelContrato(), 'avisoId': 'retirado'},
        notify: notify,
      );
      await atenderPushEnFondo(
        {...datosDelContrato(), 'distancia': 'cerca'},
        notify: notify,
      );

      expect(fired, isEmpty);
    });
  });

  test('el historial guarda y lee el id del servidor', () {
    final e = AlertHistoryEntry(
      busId: 'B',
      routeId: 'R',
      createdAt: DateTime(2026, 10, 2),
      servidorId: 'srv-9',
    );
    final leida = AlertHistoryEntry.fromJson(e.toJson());
    expect(leida.servidorId, 'srv-9');
    expect(leida.copyWith(refLat: 1, refLon: 2).servidorId, 'srv-9');
    expect(leida.conServidor(null).servidorId, isNull);
    expect(
      AlertHistoryEntry.fromJson({...e.toJson()}..remove('servidorId'))
          .servidorId,
      isNull,
    );
  });
}
