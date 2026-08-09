import 'dart:math';
import 'package:ya_viene_core/ya_viene_core.dart';

const double _earthRadiusMeters = 6371000;

double haversineMeters(double lat1, double lon1, double lat2, double lon2) {
  final dLat = _toRad(lat2 - lat1);
  final dLon = _toRad(lon2 - lon1);
  final a = pow(sin(dLat / 2), 2) +
      cos(_toRad(lat1)) * cos(_toRad(lat2)) * pow(sin(dLon / 2), 2);
  return 2 * _earthRadiusMeters * asin(sqrt(a));
}

/// Proyección de un punto sobre una polilínea: distancia al recorrido y
/// posición medida en metros desde el inicio del recorrido.
typedef PolylineProjection = ({double distanceMeters, double alongMeters});

/// Proyecta [p] sobre la polilínea [polyline] usando coordenadas locales
/// (equirectangulares, válido a distancias de ciudad).
PolylineProjection projectOntoPolyline(
    GeoPoint p, List<GeoPoint> polyline) {
  if (polyline.length < 2) {
    return (distanceMeters: 0.0, alongMeters: 0.0);
  }

  final midLat = _toRad(p.lat);
  const metersPerLat = 111320.0;
  final metersPerLon = metersPerLat * cos(midLat);

  double px(double lat, double lon) => lon * metersPerLon;
  double py(double lat, double lon) => lat * metersPerLat;

  final px_ = px(p.lat, p.lon);
  final py_ = py(p.lat, p.lon);

  var bestDistance = double.infinity;
  var bestAlong = 0.0;
  var cumulative = 0.0;
  for (var i = 0; i < polyline.length - 1; i++) {
    final a = polyline[i];
    final b = polyline[i + 1];
    final ax = px(a.lat, a.lon);
    final ay = py(a.lat, a.lon);
    final bx = px(b.lat, b.lon);
    final by = py(b.lat, b.lon);
    final dx = bx - ax;
    final dy = by - ay;
    final lenSq = dx * dx + dy * dy;
    if (lenSq > 0) {
      final t = (((px_ - ax) * dx + (py_ - ay) * dy) / lenSq).clamp(0.0, 1.0);
      final cx = ax + dx * t;
      final cy = ay + dy * t;
      final distance =
          sqrt((px_ - cx) * (px_ - cx) + (py_ - cy) * (py_ - cy));
      final segLength = sqrt(lenSq);
      if (distance < bestDistance) {
        bestDistance = distance;
        bestAlong = cumulative + segLength * t;
      }
    }
    cumulative += sqrt(lenSq);
  }
  return (distanceMeters: bestDistance, alongMeters: bestAlong);
}

double _toRad(double deg) => deg * pi / 180;
