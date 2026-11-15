import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import 'package:ya_viene_pasajero/features/viaje/lugares_del_viaje.dart';
import 'package:ya_viene_pasajero/features/viaje/trazo_del_viaje.dart';

// Una calle recta de oeste a este por la latitud 11, de 3 km.
const _lat = 11.0;
double _lon(double metros) => -74.80 + metros / 109290;
GeoPoint _p(double metros, [double norte = 0]) =>
    GeoPoint(lat: _lat + norte / 110574, lon: _lon(metros));

// Un metro, en grados, a esta latitud: la tolerancia del dibujo.
const _unMetro = 1 / 109290;
Matcher _cerca(GeoPoint p) => isA<GeoPoint>()
    .having((g) => g.lat, 'lat', closeTo(p.lat, _unMetro))
    .having((g) => g.lon, 'lon', closeTo(p.lon, _unMetro));

RedDeRutas _red() => RedDeRutas([
      RutaDeLaRed(
        id: 'R-1',
        empresa: 'EMP-01',
        medible:
            RutaMedible.de([for (var m = 0.0; m <= 3000; m += 100) _p(m)])!,
      ),
    ]);

Viaje _viaje() {
  final origen = Lugar(punto: _p(450, 80), origen: OrigenLugar.gps);
  final destino = Lugar(punto: _p(2420, -60), origen: OrigenLugar.pin);
  return Viaje(origen: origen, destino: destino, tramos: [
    TramoAPie(desde: origen.punto, hasta: _p(450), metros: 80),
    TramoEnBus(
      ruta: 'R-1',
      empresa: 'EMP-01',
      subida: PuntoDeRuta(
        ruta: 'R-1',
        avance: 450,
        punto: _p(450),
        caminata: 80,
      ),
      bajada:
          PuntoDeRuta(ruta: 'R-1', avance: 2420, punto: _p(2420), caminata: 60),
      metrosPorLaRuta: 1970,
    ),
    TramoAPie(desde: _p(2420), hasta: destino.punto, metros: 60),
  ]);
}

void main() {
  group('trazarViaje', () {
    test('la caminata en recta, el bus por la ruta y los puntos del viaje', () {
      final trazo = trazarViaje(_viaje(), _red());
      expect(trazo.caminatas, [
        [_p(450, 80), _p(450)],
        [_p(2420), _p(2420, -60)],
      ]);
      final bus = trazo.enBus.single;
      // puntoEn interpola: el mismo punto, a centímetros.
      expect(bus.first, _cerca(_p(450)));
      expect(bus.last, _cerca(_p(2420)));
      // Pasa por cada esquina de la ruta entre las dos: 500, 600 … 2400.
      expect(bus.length, 2 + 20);
      expect(trazo.subidas, [_p(450)]);
      expect(trazo.bajadas, [_p(2420)]);
      expect(trazo.origen, _p(450, 80));
      expect(trazo.destino, _p(2420, -60));
    });

    test('una ruta que ya no está en la red se dibuja recta de punta a punta',
        () {
      final trazo = trazarViaje(_viaje(), RedDeRutas(const []));
      expect(trazo.enBus.single, [_p(450), _p(2420)]);
    });

    test('la caja abarca todo lo dibujado', () {
      final caja = trazarViaje(_viaje(), _red()).caja;
      expect(caja.minLat, closeTo(_lat - 60 / 110574, _unMetro));
      expect(caja.maxLat, closeTo(_lat + 80 / 110574, _unMetro));
      expect(caja.minLon, closeTo(_lon(450), _unMetro));
      expect(caja.maxLon, closeTo(_lon(2420), _unMetro));
    });

    test('el GeoJSON de MapLibre lleva lon antes que lat', () {
      final json = lineasAGeoJson([
        [_p(0), _p(100)]
      ]);
      final features = json['features'] as List;
      final coords = (features.single as Map)['geometry']['coordinates'];
      expect(coords, [
        [_lon(0), _lat],
        [_lon(100), _lat],
      ]);
      expect(puntosAGeoJson([_p(0)])['features'], hasLength(1));
    });
  });

  group('AlmacenEnPreferencias', () {
    test('guarda, lee y borra en las preferencias del teléfono', () async {
      SharedPreferences.setMockInitialValues({});
      final almacen = AlmacenEnPreferencias();
      expect(await almacen.leer(), isNull);
      await almacen.escribir('[1]');
      expect(await almacen.leer(), '[1]');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(AlmacenEnPreferencias.llave), '[1]');
      await almacen.escribir(null);
      expect(prefs.containsKey(AlmacenEnPreferencias.llave), isFalse);
    });
  });
}
