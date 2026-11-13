// El pedazo de ruta que se pinta en el mapa cuando se elige un viaje: de
// donde se sube a donde se baja, por la calle y no en línea recta.
import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

import 'dibujo.dart';

/// Las coordenadas planas de la ruta se apartan menos del 0,1 %: en estos
/// dibujos de pocos kilómetros, un metro largo (1e-5 grados).
void _igual(List<GeoPoint> trazo, List<GeoPoint> esperado) {
  expect(trazo, hasLength(esperado.length));
  for (var i = 0; i < trazo.length; i++) {
    expect(trazo[i].lat, closeTo(esperado[i].lat, 1e-5), reason: 'lat de $i');
    expect(trazo[i].lon, closeTo(esperado[i].lon, 1e-5), reason: 'lon de $i');
  }
}

void main() {
  test('en un tramo recto son solo la subida y la bajada', () {
    final trazo = recta().medible.trazoEntre(500, 1500);

    _igual(trazo, [m(500, 0), m(1500, 0)]);
  });

  test('pasa por cada esquina de la ruta entre los dos puntos', () {
    final trazo = idaYVuelta().medible.trazoEntre(1500, 2600);

    _igual(trazo, [m(1500, 0), m(2000, 0), m(2000, 100), m(1500, 100)]);
  });

  test('en la circular cruza el cierre de la vuelta', () {
    final trazo = circular().medible.trazoEntre(11000, 1000);

    _igual(trazo, [m(0, 1000), m(0, 0), m(1000, 0)]);
  });

  test('una esquina que cae justo en la subida no se repite', () {
    final trazo = idaYVuelta().medible.trazoEntre(2000, 2100);

    _igual(trazo, [m(2000, 0), m(2000, 100)]);
  });
}
