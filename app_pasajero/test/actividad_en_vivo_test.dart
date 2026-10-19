import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import 'package:ya_viene_pasajero/core/services/actividad_en_vivo.dart';
import 'package:ya_viene_pasajero/core/utils/color_empresa.dart';
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
  BusPosition bus(double dLat) => BusPosition(
        busId: 'A-1',
        routeId: 'R1',
        lat: lat + dLat,
        lon: lon,
        heading: 0,
        speedKmh: 20,
        timestamp: DateTime.now(),
        isGhostBus: false,
      );

  late _EnVivoFalso enVivo;
  late List<BusPosition> posiciones;

  ProviderContainer contenedor() {
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
                    required int distanceMeters}) async =>
                true,
            retirar: (_) async {},
            enVivo: enVivo,
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
    c.read(selectedRouteProvider.notifier).select(const RouteInfo(
          id: 'R1',
          name: 'B18 Tcherassi',
          companyId: 'C1',
        ));
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
    posiciones = [bus(0.0135)];
  });

  test('con el aviso armado, la actividad dice la distancia y lo que falta',
      () async {
    final avisos = await armado(contenedor());

    await avisos.check();

    final e = enVivo.mostrados.single;
    expect(e.busId, 'A-1');
    expect(e.codigo, 'B18');
    expect(e.ruta, 'Tcherassi');
    expect(e.color, colorEmpresa('C1').toARGB32());
    expect(e.distancia, '1,5 km');
    expect(e.aviso, 'Te avisamos a 1,0 km');
    expect(e.avance, closeTo(0.5, 0.02));
    expect(e.avanceAviso, closeTo(2 / 3, 0.001));
    expect(e.aMapa()['avance'], e.avance);
    expect(e.aMapa()['avanceAviso'], e.avanceAviso);
    expect(enVivo.terminados, isEmpty);
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
}
