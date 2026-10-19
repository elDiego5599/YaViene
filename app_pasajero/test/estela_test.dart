import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import 'package:ya_viene_pasajero/features/map/presentation/utils/estela.dart';
import 'package:ya_viene_pasajero/features/map/presentation/utils/geo.dart';

// La estela del bus: un rastro tenue de por dónde viene, que se apaga hacia
// atrás (dueño, 2026-10-19).
void main() {
  // Unos 11 m por cada 0,0001° de latitud.
  GeoPoint norte(double metros) =>
      GeoPoint(lat: 11 + metros / 111320, lon: -74.8);

  double largo(List<GeoPoint> linea) {
    var total = 0.0;
    for (var i = 1; i < linea.length; i++) {
      total += haversineMeters(
          linea[i - 1].lat, linea[i - 1].lon, linea[i].lat, linea[i].lon);
    }
    return total;
  }

  group('sumarAEstela', () {
    test('suma el punto nuevo al final', () {
      final h = sumarAEstela([norte(0)], norte(20));
      expect(h.length, 2);
      expect(h.last.lat, norte(20).lat);
    });

    test('un salto de más de 300 m empieza otra estela', () {
      final h = sumarAEstela([norte(0), norte(20)], norte(400));
      expect(h, hasLength(1));
      expect(h.single.lat, norte(400).lat);
    });

    test('olvida lo que queda más atrás del largo, menos el punto del borde',
        () {
      var h = <GeoPoint>[];
      for (var m = 0.0; m <= 480; m += 60) {
        h = sumarAEstela(h, norte(m));
      }
      // De 480 a 300 van 180 m, menos del largo: el de 240 es el borde y lo
      // de antes sobra.
      expect(h.first.lat, closeTo(norte(240).lat, 1e-9));
      expect(h.last.lat, closeTo(norte(480).lat, 1e-9));
    });
  });

  group('capasDeEstela', () {
    test('sin dos puntos distintos no hay estela', () {
      expect(capasDeEstela(const []), isEmpty);
      expect(capasDeEstela([norte(0)]), isEmpty);
      expect(capasDeEstela([norte(0), norte(0)]), isEmpty);
    });

    test('capas cada vez más cortas, todas terminan en el bus', () {
      final capas = capasDeEstela([norte(0), norte(150), norte(400)]);
      expect(capas, hasLength(kCapasEstela));
      for (var i = 0; i < capas.length; i++) {
        expect(largo(capas[i]),
            closeTo(kLargoEstela * (kCapasEstela - i) / kCapasEstela, 0.5));
        expect(capas[i].last.lat, norte(400).lat);
      }
    });

    test('una estela corta también se apaga hacia atrás', () {
      final capas = capasDeEstela([norte(0), norte(40)]);
      expect(capas, hasLength(kCapasEstela));
      expect(largo(capas.first), closeTo(40, 0.5));
      expect(largo(capas.last), closeTo(40 / kCapasEstela, 0.5));
    });
  });
}
