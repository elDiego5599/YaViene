// Utilidades del pin: el círculo de 2 km alrededor del punto de espera y la
// caminada del pin a la ruta. Antes el círculo era un método privado de
// map_widget.dart.
import 'dart:math' as math;

import 'package:ya_viene_core/ya_viene_core.dart';

import '../utils/geo.dart';

Map<String, dynamic> radiusCircleFeature(
  double lat,
  double lon,
  double radiusMeters,
) {
  const steps = 48;
  final coordinates = <List<double>>[];
  for (var i = 0; i < steps; i++) {
    final angle = 2 * math.pi * i / steps;
    final dLat = (radiusMeters * math.cos(angle)) / 111320;
    final dLon = (radiusMeters * math.sin(angle)) /
        (111320 * math.cos(lat * math.pi / 180));
    coordinates.add([lon + dLon, lat + dLat]);
  }
  coordinates.add(coordinates.first);
  return {
    'type': 'Feature',
    'geometry': {
      'type': 'Polygon',
      'coordinates': [coordinates],
    },
    'properties': const {},
  };
}

/// Menos que esto del pin a la ruta es estar en ella: la línea quedaría
/// debajo de la punta del pin (15 m son 3 pt a zoom 15) y el punto de
/// espera, pegado a ella, solo ensuciaría.
const double caminadaMinimaMetros = 15;

/// La caminada del pin ([lat], [lon]) al punto de la [ruta] donde se espera
/// el bus ([RutaMedible.puntoDeEspera]): una línea y el punto donde acaba.
///
/// La distancia del bus se cuenta hasta ese punto más esta caminada; sin
/// verla, quien pone el pin entre dos calles no sabe por cuál se mide
/// (dueño, 2026-11-04). Sin ruta, o con el pin sobre ella, va vacía.
Map<String, dynamic> caminadaHastaLaRuta(
  RutaMedible? ruta,
  double lat,
  double lon,
) {
  final espera = ruta?.puntoDeEspera(GeoPoint(lat: lat, lon: lon));
  final caminaAlgo = espera != null &&
      haversineMeters(lat, lon, espera.lat, espera.lon) >= caminadaMinimaMetros;
  return {
    'type': 'FeatureCollection',
    'features': [
      if (caminaAlgo) ...[
        {
          'type': 'Feature',
          'geometry': {
            'type': 'LineString',
            'coordinates': [
              [lon, lat],
              [espera.lon, espera.lat],
            ],
          },
          'properties': const {},
        },
        {
          'type': 'Feature',
          'geometry': {
            'type': 'Point',
            'coordinates': [espera.lon, espera.lat],
          },
          'properties': const {},
        },
      ],
    ],
  };
}
