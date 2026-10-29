import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import 'package:ya_viene_pasajero/core/services/actividad_en_vivo.dart';
import 'package:ya_viene_pasajero/core/services/mantener_vivo.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/tracking_providers.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/user_location_provider.dart';
import 'package:ya_viene_pasajero/features/notifications/presentation/providers/proximity_alerts_provider.dart';

class _TestUserLocation extends UserLocationNotifier {
  void set(UserLocationState state) => this.state = state;
}

class _EnVivoFalso implements ActividadEnVivo {
  final mostrados = <EstadoEnVivo>[];
  final terminados = <({String busId, bool llego})>[];

  @override
  Future<void> mostrar(EstadoEnVivo estado) async => mostrados.add(estado);

  @override
  Future<void> terminar(String busId, {required bool llego}) async =>
      terminados.add((busId: busId, llego: llego));
}

class _MantenerVivoFalso implements ServicioMantenerVivo {
  int inicios = 0;
  int paradas = 0;

  @override
  Future<void> iniciar() async => inicios++;

  @override
  Future<void> detener() async => paradas++;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ActivityKit conserva viva solo la actividad actual del bus seguido',
      () {
    final nativo = File('ios/Runner/ActividadEnVivo.swift').readAsStringSync();

    expect(nativo, contains(r'$0.activityState == .active'));
    expect(nativo, contains(r'$0.id != viva?.id'));
    expect(nativo, contains('dismissalPolicy: .immediate'));
  });

  test('el avance: 3 km o más es el arranque, 0 m es tu punto', () {
    expect(EstadoEnVivo.avanceDe(3000), 0);
    expect(EstadoEnVivo.avanceDe(5000), 0);
    expect(EstadoEnVivo.avanceDe(1500), 0.5);
    expect(EstadoEnVivo.avanceDe(0), 1);
    expect(EstadoEnVivo.avanceDe(-5), 1);
  });

  const lat = 10.9878;
  const lon = -74.7889;
  // 0,0135° de latitud son unos 1.500 m.
  BusPosition bus(double dLat, {String busId = 'A-1'}) => BusPosition(
        busId: busId,
        routeId: 'R1',
        lat: lat + dLat,
        lon: lon,
        heading: 0,
        speedKmh: 20,
        timestamp: DateTime.now(),
        isGhostBus: false,
      );

  late _EnVivoFalso enVivo;
  late _MantenerVivoFalso mantenerVivo;
  late List<BusPosition> posiciones;

  ProviderContainer contenedor({
    DateTime Function()? ahora,
    bool seleccionarRuta = true,
    Future<bool> Function()? avisar,
  }) {
    final c = ProviderContainer(overrides: [
      userLocationProvider.overrideWith((ref) => _TestUserLocation()),
      busPositionsSourceProvider.overrideWith(
        (ref, routeId) => Stream.value(posiciones),
      ),
      proximityAlertsProvider.overrideWith((ref) => ProximityAlertsNotifier(
            ref,
            notify: (
                    {required String busId,
                    String? routeName,
                    String? routeId,
                    String? companyId,
                    required int distanceMeters}) =>
                avisar?.call() ?? Future.value(true),
            retirar: (_) async {},
            permiso: () async => true,
            ahora: ahora,
            enVivo: enVivo,
            mantenerVivo: mantenerVivo,
            sentir: () async {},
          )),
    ]);
    addTearDown(c.dispose);
    (c.read(userLocationProvider.notifier) as _TestUserLocation).set(
      UserLocationState(
        mode: UserLocationMode.gps,
        lat: lat,
        lon: lon,
        updatedAt: DateTime.now(),
      ),
    );
    if (seleccionarRuta) {
      c.read(selectedRouteProvider.notifier).select(const RouteInfo(
            id: 'R1',
            name: 'B18 Tcherassi',
            companyId: 'C1',
          ));
    }
    return c;
  }

  Future<ProximityAlertsNotifier> armado(ProviderContainer c) async {
    final avisos = c.read(proximityAlertsProvider.notifier);
    c.read(activeAlertsProvider.notifier).activateAlert('A-1');
    avisos.armAlert('A-1', 'R1');
    await Future<void>.delayed(Duration.zero);
    return avisos;
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    enVivo = _EnVivoFalso();
    mantenerVivo = _MantenerVivoFalso();
    posiciones = [bus(0.0135)];
  });

  test('con el aviso armado, la actividad dice la distancia y lo que falta',
      () async {
    final avisos = await armado(contenedor());

    await avisos.check();

    final e = enVivo.mostrados.single;
    expect(e.busId, 'A-1');
    expect(e.routeId, 'R1');
    expect(e.ruta, 'Tcherassi');
    expect(e.distancia, '1,5 km');
    expect(e.aviso, 'Te avisamos a 1,0 km');
    expect(e.avance, closeTo(0.5, 0.02));
    expect(e.avanceAviso, closeTo(2 / 3, 0.001));
    expect(e.aMapa()['avance'], e.avance);
    expect(e.aMapa()['avanceAviso'], e.avanceAviso);
    // Sin ficha de la ruta: la isla y la pantalla bloqueada llevan el logo
    // de Ya Viene (dueño, 2026-10-21).
    expect(
        e.aMapa().keys,
        unorderedEquals([
          'busId',
          'routeId',
          'companyId',
          'placa',
          'ruta',
          'distancia',
          'aviso',
          'avance',
          'avanceAviso',
          'llego'
        ]));
    expect(e.llego, isFalse);
    expect(enVivo.terminados, isEmpty);
  });

  test('restaurado dentro del radio publica actividad antes de llegar',
      () async {
    SharedPreferences.setMockInitialValues({
      'alert_history': jsonEncode([
        {
          'busId': 'A-1',
          'routeId': 'R1',
          'routeName': 'B18 Tcherassi',
          'companyId': 'C1',
          'createdAt': DateTime.now().toIso8601String(),
          'refLat': null,
          'refLon': null,
          'radioM': 1000,
        }
      ]),
    });
    posiciones = [bus(0.0036)]; // Unos 400 m: dentro del radio de 1 km.
    final c = contenedor(seleccionarRuta: false);
    final avisos = c.read(proximityAlertsProvider.notifier);

    await avisos.restore();
    await Future<void>.delayed(Duration.zero);
    expect(c.read(activeAlertsProvider), {'A-1'});
    expect(c.read(selectedRouteProvider), isNull);
    expect(c.read(selectedCompanyProvider), isNull);

    await avisos.check();
    await Future<void>.delayed(Duration.zero);

    expect(enVivo.mostrados, hasLength(1));
    expect(enVivo.mostrados.single.busId, 'A-1');
    expect(enVivo.mostrados.single.routeId, 'R1');
    expect(enVivo.mostrados.single.distancia, '400 m');
    expect(enVivo.terminados, [(busId: 'A-1', llego: true)]);
  });

  // El aviso es local, no push: con la app suspendida puede no salir a
  // tiempo, pero la actividad dice «cerca» en cuanto el bus entra al radio
  // (dueño, 2026-10-29: con un aviso de 1 km se quedó en «Está a 985 m»).
  test('dentro del radio la actividad dice cerca aunque el aviso no salga',
      () async {
    posiciones = [bus(0.00886)]; // Unos 985 m: dentro del radio de 1 km.
    final avisos = await armado(contenedor(
      avisar: () => Completer<bool>().future,
    ));

    unawaited(avisos.check());
    await Future<void>.delayed(Duration.zero);

    final e = enVivo.mostrados.last;
    expect(e.distancia, '985 m');
    expect(e.llego, isTrue);
    expect(e.aMapa()['llego'], isTrue);
  });

  test('pasados 10 km, la cifra lleva el decimal como la hoja', () async {
    // 0,0953° son unos 10,6 km: la hoja dice «10,6» y la isla decía «11».
    posiciones = [bus(0.0953)];
    final avisos = await armado(contenedor());

    await avisos.check();

    expect(enVivo.mostrados.single.distancia, '10,6 km');
  });

  test('sin cambio en lo que se lee, no se manda otra vez', () async {
    final avisos = await armado(contenedor());

    await avisos.check();
    await avisos.check();

    expect(enVivo.mostrados, hasLength(1));
  });

  test('reenviar la actividad a los 30 segundos aunque no cambie la distancia',
      () async {
    var reloj = DateTime.now();
    final avisos = await armado(contenedor(ahora: () => reloj));

    await avisos.check();
    reloj = reloj.add(const Duration(seconds: 31));
    await avisos.check();

    expect(enVivo.mostrados, hasLength(2));
    expect(enVivo.mostrados[0].distancia, enVivo.mostrados[1].distancia);
    expect(enVivo.mostrados[0].avance, enVivo.mostrados[1].avance);
  });

  test('el avance actualiza la actividad dentro del mismo paso de distancia',
      () async {
    final c = contenedor();
    final avisos = await armado(c);
    await avisos.check();

    posiciones = [bus(0.0133)];
    c.invalidate(busPositionsSourceProvider('R1'));
    await Future<void>.delayed(Duration.zero);
    await avisos.check();

    expect(enVivo.mostrados, hasLength(2));
    expect(enVivo.mostrados[0].distancia, enVivo.mostrados[1].distancia);
    expect(enVivo.mostrados[0].avance.toStringAsFixed(2),
        isNot(enVivo.mostrados[1].avance.toStringAsFixed(2)));
  });

  test('«Cambiar» manda la distancia nueva del aviso', () async {
    final avisos = await armado(contenedor());
    await avisos.check();

    avisos.cambiarRadio('A-1', 800);
    await avisos.check();

    expect(enVivo.mostrados.map((e) => e.aviso),
        ['Te avisamos a 1,0 km', 'Te avisamos a 800 m']);
  });

  test('cuando suena, la actividad termina diciendo que llegó', () async {
    final c = contenedor();
    final avisos = await armado(c);
    await avisos.check();

    posiciones = [bus(0.004)];
    c.invalidate(busPositionsSourceProvider('R1'));
    await Future<void>.delayed(Duration.zero);
    await avisos.check();

    expect(enVivo.terminados, [(busId: 'A-1', llego: true)]);
  });

  test('quitar el aviso termina la actividad sin decir que llegó', () async {
    final avisos = await armado(contenedor());
    await avisos.check();

    avisos.disarmAlert('A-1');
    avisos.disarmAlert('A-1');

    expect(enVivo.terminados, [(busId: 'A-1', llego: false)]);
  });

  test('armar el primer aviso inicia el mantenimiento en vivo', () async {
    await armado(contenedor());

    expect(mantenerVivo.inicios, 1);
  });

  test('la actividad incluye la placa derivada del id del bus', () async {
    posiciones = [bus(0.0135, busId: 'BUS-SQA223')];
    final c = contenedor();
    final avisos = c.read(proximityAlertsProvider.notifier);
    c.read(activeAlertsProvider.notifier).activateAlert('BUS-SQA223');
    avisos.armAlert('BUS-SQA223', 'R1');
    await Future<void>.delayed(Duration.zero);

    await avisos.check();

    expect(enVivo.mostrados.single.placa, 'SQA223');
  });

  test('desarmar el último aviso detiene el mantenimiento en vivo', () async {
    final avisos = await armado(contenedor());

    avisos.disarmAlert('A-1');

    expect(mantenerVivo.paradas, 1);
  });

  test('el segundo bus no toma el stream de mantenimiento', () async {
    final c = contenedor();
    final avisos = await armado(c);

    expect(c.read(activeAlertsProvider.notifier).activateAlert('A-2'), isFalse);
    expect(c.read(activeAlertsProvider), {'A-1'});
    expect(mantenerVivo.inicios, 1);

    avisos.disarmAlert('A-1');
    expect(mantenerVivo.paradas, 1);
  });

  test('clear detiene el mantenimiento en vivo', () async {
    final avisos = await armado(contenedor());

    avisos.clear();

    expect(mantenerVivo.paradas, 1);
  });

  test('dispose detiene el mantenimiento en vivo', () async {
    final c = contenedor();
    await armado(c);

    c.dispose();

    expect(mantenerVivo.paradas, 1);
  });
}
