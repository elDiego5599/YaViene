import 'dart:math' as math;

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
