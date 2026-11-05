// Utilidades del pin: el círculo de 2 km alrededor del punto de espera y el
// punto de la ruta donde cae el pin. Antes el círculo era un método privado
// de map_widget.dart.
import 'dart:math' as math;

import 'package:ya_viene_core/ya_viene_core.dart';

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

/// Dónde cae el pin soltado en ([lat], [lon]): en el punto de la [ruta]
/// donde se toma el bus ([RutaMedible.puntoDeEspera]).
///
/// El pin marca dónde se toma la ruta, no dónde está la persona: el bus
/// nunca pasa por fuera de ella, y sumarle la caminada hasta el pin medía
/// por la calle que no era (la 72 va de ida por la 23 y vuelve por la 24;
/// dueño, 2026-11-05). Sin ruta elegida, se queda donde lo soltaron.
GeoPoint dondeSeTomaLaRuta(RutaMedible? ruta, double lat, double lon) {
  final pin = GeoPoint(lat: lat, lon: lon);
  return ruta?.puntoDeEspera(pin) ?? pin;
}
