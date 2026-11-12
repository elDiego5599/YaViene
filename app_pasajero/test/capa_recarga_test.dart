import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

import 'package:ya_viene_pasajero/features/recarga/capa_recarga.dart';

PuntoDeRecarga _punto(String id, double lat, double lon) => PuntoDeRecarga(
      id: id,
      nombre: 'PUNTO $id',
      direccion: 'Calle $id',
      lat: lat,
      lon: lon,
      fuente: const FuenteEjemplo(),
    );

void main() {
  group('puntosAGeoJson', () {
    test('un Point por punto, con [lon, lat] y solo su id (sin nombres)', () {
      final geo = puntosAGeoJson([_punto('a', 10.98, -74.8)]);
      expect(geo['type'], 'FeatureCollection');
      final f = (geo['features'] as List).single as Map<String, dynamic>;
      expect(f['geometry'], {
        'type': 'Point',
        'coordinates': [-74.8, 10.98],
      });
      expect(f['properties'], {'id': 'a'});
    });

    test('sin puntos, una colección vacía válida', () {
      expect(puntosAGeoJson(const [])['features'], isEmpty);
    });
  });

  group('idDeFeature', () {
    test('lee el id de las propiedades o devuelve null', () {
      expect(
          idDeFeature({
            'properties': {'id': 'x'}
          }),
          'x');
      expect(idDeFeature({'properties': {}}), isNull);
      expect(idDeFeature({}), isNull);
    });
  });
}
