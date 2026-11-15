import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/tracking_providers.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/user_location_provider.dart';
import 'package:ya_viene_pasajero/features/viaje/planificador.dart';

// Una calle recta de oeste a este por la latitud 11, de 3 km, y un bus que
// la anda. A esa latitud un grado de longitud son unos 109,3 km.
const _lat = 11.0;
const _lon0 = -74.80;
double _lon(double metros) => _lon0 + metros / 109290;
GeoPoint _p(double metros, [double norte = 0]) =>
    GeoPoint(lat: _lat + norte / 110574, lon: _lon(metros));

RutaSobusa _ruta(String id, {double largo = 3000}) => RutaSobusa(
      routeId: id,
      name: 'Ruta $id',
      terminalA: null,
      terminalB: null,
      lengthKm: largo / 1000,
      waypoints: [for (var m = 0.0; m <= largo; m += 100) _p(m)],
      paradas: const [],
    );

Lugar _lugar(double metros, [double norte = 0]) =>
    Lugar(punto: _p(metros, norte), origen: OrigenLugar.pin);

BusPosition _bus(String id, double metros) => BusPosition(
      busId: id,
      routeId: 'R-1',
      lat: _lat,
      lon: _lon(metros),
      heading: 90,
      speedKmh: 20,
      timestamp: DateTime(2026, 11, 14, 15),
      isGhostBus: false,
    );

class _Ubicacion extends UserLocationNotifier {
  _Ubicacion(UserLocationState inicial) {
    state = inicial;
  }
}

void main() {
  group('armarRed', () {
    test('con el catálogo, solo las rutas que tienen empresa, con la suya', () {
      final red = armarRed(
        [_ruta('R-1'), _ruta('R-2')],
        const {'R-1': 'EMP-01'},
      );
      expect(red.rutas.map((r) => (r.id, r.empresa)), [('R-1', 'EMP-01')]);
    });

    test('sin catálogo (sin red), todas, sin empresa', () {
      final red = armarRed([_ruta('R-1'), _ruta('R-2')], const {});
      expect(
          red.rutas.map((r) => (r.id, r.empresa)), [('R-1', ''), ('R-2', '')]);
    });

    test('deja fuera la ruta que no se puede medir', () {
      final rota = RutaSobusa(
        routeId: 'R-9',
        name: 'Rota',
        terminalA: null,
        terminalB: null,
        lengthKm: 0,
        waypoints: [_p(0)],
        paradas: const [],
      );
      expect(armarRed([_ruta('R-1'), rota], const {}).rutas.map((r) => r.id),
          ['R-1']);
    });
  });

  group('textoDeLlegada', () {
    final tresYCuarenta = DateTime(2026, 11, 14, 15, 40, 20);

    test('un rango de reloj, con la mañana o la tarde una sola vez', () {
      expect(
        textoDeLlegada(
          tresYCuarenta,
          const RangoDeLlegada(
            desde: Duration(minutes: 2),
            hasta: Duration(minutes: 6, seconds: 30),
            simulado: false,
          ),
        ),
        'Llega de 3:42 a 3:47 p. m.',
      );
    });

    test(
        'el borde de abajo se redondea hacia atrás y el de arriba hacia '
        'adelante: el rango nunca promete más de lo que se sabe', () {
      expect(
        textoDeLlegada(
          DateTime(2026, 11, 14, 9, 0, 50),
          const RangoDeLlegada(
            desde: Duration(seconds: 5),
            hasta: Duration(seconds: 20),
            simulado: false,
          ),
        ),
        'Llega de 9:00 a 9:02 a. m.',
      );
    });

    test('al cruzar el mediodía dice las dos', () {
      expect(
        textoDeLlegada(
          DateTime(2026, 11, 14, 11, 57),
          const RangoDeLlegada(
            desde: Duration(minutes: 1),
            hasta: Duration(minutes: 6),
            simulado: false,
          ),
        ),
        'Llega de 11:58 a. m. a 12:03 p. m.',
      );
    });

    test('a medianoche son las 12', () {
      expect(
        textoDeLlegada(
          DateTime(2026, 11, 14, 0, 3),
          const RangoDeLlegada(
            desde: Duration(minutes: 1),
            hasta: Duration(minutes: 2),
            simulado: false,
          ),
        ),
        'Llega de 12:04 a 12:05 a. m.',
      );
    });
  });

  group('caminataHablada', () {
    test('de 50 en 50 m, como se dice, nunca cero', () {
      expect(caminataHablada(312), 'unos 300 m a pie');
      expect(caminataHablada(330), 'unos 350 m a pie');
      expect(caminataHablada(12), 'unos 50 m a pie');
    });

    test('desde 1 km, en km con una cifra decimal', () {
      expect(caminataHablada(980), 'unos 1 km a pie');
      expect(caminataHablada(1240), 'unos 1,2 km a pie');
    });

    test('sin caminar, lo dice', () {
      expect(caminataHablada(0), 'sin caminar');
    });
  });

  group('planificadorProvider', () {
    ProviderContainer contenedor(UserLocationState ubicacion,
        {List<Override> mas = const []}) {
      final c = ProviderContainer(overrides: [
        userLocationProvider.overrideWith((ref) => _Ubicacion(ubicacion)),
        redDeRutasProvider.overrideWith((ref) async => armarRed([
              _ruta('R-1')
            ], const {
              'R-1': 'EMP-01',
            })),
        ...mas,
      ]);
      addTearDown(c.dispose);
      return c;
    }

    test('arranca desde el GPS, como «Tu ubicación»', () {
      final c = contenedor(UserLocationState(
        mode: UserLocationMode.gps,
        lat: _lat,
        lon: _lon(100),
      ));
      final estado = c.read(planificadorProvider);
      expect(
        estado.origen,
        Lugar(
          punto: GeoPoint(lat: _lat, lon: _lon(100)),
          origen: OrigenLugar.gps,
        ),
      );
      expect(estado.destino, isNull);
    });

    test('con el pin puesto arranca desde el pin', () {
      final c = contenedor(UserLocationState(
        mode: UserLocationMode.manual,
        lat: _lat,
        lon: _lon(100),
      ));
      expect(c.read(planificadorProvider).origen?.origen, OrigenLugar.pin);
    });

    test('sin ubicación arranca sin origen', () {
      final c =
          contenedor(const UserLocationState(mode: UserLocationMode.denied));
      expect(c.read(planificadorProvider).origen, isNull);
    });

    test('invertir cambia los dos puntos y vuelve a la primera opción', () {
      final c = contenedor(const UserLocationState());
      final p = c.read(planificadorProvider.notifier)
        ..ponerOrigen(_lugar(0))
        ..ponerDestino(_lugar(2000))
        ..elegir(1)
        ..invertir();
      expect(c.read(planificadorProvider).origen, _lugar(2000));
      expect(c.read(planificadorProvider).destino, _lugar(0));
      expect(c.read(planificadorProvider).elegida, 0);
      p.ponerDestino(_lugar(500));
      expect(c.read(planificadorProvider).elegida, 0);
    });

    test('sin los dos puntos no hay plan', () async {
      final c = contenedor(const UserLocationState());
      c.read(planificadorProvider.notifier).ponerDestino(_lugar(2000));
      expect(c.read(planProvider), isNull);
    });

    test('con los dos puntos y la red, el plan', () async {
      final c = contenedor(const UserLocationState());
      c.read(planificadorProvider.notifier)
        ..ponerOrigen(_lugar(100, 50))
        ..ponerDestino(_lugar(2500, 50));
      await c.read(redDeRutasProvider.future);
      final plan = c.read(planProvider)!.requireValue;
      expect(plan, isA<PlanConViajes>());
      final tramo = (plan as PlanConViajes).viajes.first.enBus.single;
      expect(tramo.ruta, 'R-1');
      expect(tramo.empresa, 'EMP-01');
    });

    test('mientras se arma la red, cargando', () {
      final c = contenedor(const UserLocationState());
      c.read(planificadorProvider.notifier)
        ..ponerOrigen(_lugar(100))
        ..ponerDestino(_lugar(2500));
      expect(c.read(planProvider)!.isLoading, isTrue);
    });
  });

  group('busQueVieneProvider', () {
    test('el que viene a la subida, de los buses en vivo de la ruta', () async {
      final tramo = TramoEnBus(
        ruta: 'R-1',
        empresa: 'EMP-01',
        subida: PuntoDeRuta(
            ruta: 'R-1', avance: 1000, punto: _p(1000), caminata: 0),
        bajada: PuntoDeRuta(
            ruta: 'R-1', avance: 2500, punto: _p(2500), caminata: 0),
        metrosPorLaRuta: 1500,
      );
      final c = ProviderContainer(overrides: [
        busPositionsSourceProvider.overrideWith((ref, ruta) =>
            Stream.value([_bus('a', 1500), _bus('b', 400), _bus('c', 100)])),
        routeTrajectoryProvider.overrideWith((ref, ruta) => RouteTrajectory(
              routeId: ruta,
              routeName: 'Ruta 1',
              points: [for (var m = 0.0; m <= 3000; m += 100) _p(m)],
            )),
      ]);
      addTearDown(c.dispose);
      final sub = c.listen(busQueVieneProvider(tramo), (_, __) {});
      addTearDown(sub.close);
      await c.read(busPositionsSourceProvider('R-1').future);
      final viene = c.read(busQueVieneProvider(tramo));
      expect(viene?.busId, 'b');
      expect(viene!.metrosHastaLaSubida, closeTo(600, 5));
    });
  });

  group('irAlViajeProvider', () {
    const sobusa = Company(id: 'EMP-01', name: 'Sobusa');
    const r1 = RouteInfo(id: 'R-1', name: 'C11 Silencio', companyId: 'EMP-01');

    Viaje viaje(String ruta) {
      final origen = _lugar(100, 80);
      final destino = _lugar(2500, 60);
      return Viaje(origen: origen, destino: destino, tramos: [
        TramoAPie(desde: origen.punto, hasta: _p(100), metros: 80),
        TramoEnBus(
          ruta: ruta,
          empresa: 'EMP-01',
          subida: PuntoDeRuta(
              ruta: ruta, avance: 100, punto: _p(100), caminata: 80),
          bajada: PuntoDeRuta(
              ruta: ruta, avance: 2500, punto: _p(2500), caminata: 60),
          metrosPorLaRuta: 2400,
        ),
        TramoAPie(desde: _p(2500), hasta: destino.punto, metros: 60),
      ]);
    }

    ProviderContainer contenedor() {
      SharedPreferences.setMockInitialValues({});
      final c = ProviderContainer(overrides: [
        backendUrlProvider.overrideWith(() => BackendUrl.fija('http://x')),
        companiesProvider.overrideWith((ref) async => [sobusa]),
        routesByCompanyProvider.overrideWith((ref, id) async => [r1]),
        userLocationProvider.overrideWith((ref) => _Ubicacion(
            UserLocationState(
                mode: UserLocationMode.gps, lat: _lat, lon: _lon(0)))),
      ]);
      addTearDown(c.dispose);
      return c;
    }

    test('deja el mapa con la empresa y la ruta, y el pin en la subida',
        () async {
      final c = contenedor();
      expect(await c.read(irAlViajeProvider)(viaje('R-1')), isTrue);
      expect(c.read(selectedCompanyProvider), sobusa);
      expect(c.read(selectedRouteProvider), r1);
      final ubicacion = c.read(userLocationProvider);
      expect(ubicacion.mode, UserLocationMode.manual);
      expect((ubicacion.lat, ubicacion.lon), (_p(100).lat, _p(100).lon));
      expect(ubicacion.ancla, _p(100));
    });

    test('si la ruta ya no está en el catálogo, no toca nada', () async {
      final c = contenedor();
      expect(await c.read(irAlViajeProvider)(viaje('R-9')), isFalse);
      expect(c.read(selectedRouteProvider), isNull);
      expect(c.read(userLocationProvider).mode, UserLocationMode.gps);
    });
  });
}
