import 'package:flutter/material.dart';

class BusScreenPoint {
  const BusScreenPoint({required this.busId, required this.offset});

  final String busId;
  final Offset offset;
}

/// Devuelve el bus más cercano al toque, siempre que esté dentro del radio
/// permitido. El orden de features de MapLibre no se usa para decidir.
String? nearestBusId(
  Offset tap,
  Iterable<BusScreenPoint> points, {
  double maxDistance = 32,
}) {
  String? nearest;
  var nearestSquared = double.infinity;
  for (final point in points) {
    final dx = point.offset.dx - tap.dx;
    final dy = point.offset.dy - tap.dy;
    final distanceSquared = dx * dx + dy * dy;
    if (distanceSquared < nearestSquared) {
      nearestSquared = distanceSquared;
      nearest = point.busId;
    }
  }
  if (nearest == null || nearestSquared > maxDistance * maxDistance) {
    return null;
  }
  return nearest;
}
