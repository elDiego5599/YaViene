import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Cuántas unidades del mapa nativo caben en un punto de Flutter.
///
/// MapLibre en Android entrega y recibe píxeles físicos (los toques,
/// `toScreenLocation`, el arrastre); en iOS, puntos de UIKit, que son los
/// mismos puntos lógicos de Flutter. Sin pasar a puntos, el radio de toque
/// de un bus medía un tercio en un Android de densidad 3 —por eso costaba
/// acertarle allí y no en el iPhone (dueño, 2026-10-02)— y el pulso del pin
/// y el foco de la guía caían corridos.
double escalaDelMapa(TargetPlatform plataforma, double devicePixelRatio) =>
    plataforma == TargetPlatform.android ? devicePixelRatio : 1;

/// Un punto del mapa nativo, en puntos lógicos de Flutter.
Offset aPuntoLogico(math.Point<num> punto, double escala) =>
    Offset(punto.x / escala, punto.y / escala);

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
