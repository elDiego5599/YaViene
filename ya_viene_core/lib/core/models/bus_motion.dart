// Animación suave de los buses: interpola entre dos posiciones GPS.
// Vive en el core porque la usan el mapa del pasajero y el del panel: los
// dos deslizan el bus de una fijación a la siguiente (dueño, 2026-10-07).

import 'bus_position.dart';

/// Tramo de animación de un bus entre dos fijaciones GPS.
class BusMotion {
  BusMotion({
    required this.fromLat,
    required this.fromLon,
    required this.fromHeading,
    required this.toLat,
    required this.toLon,
    required this.toHeading,
    required this.start,
    this.duration = minimo,
  });

  final double fromLat;
  final double fromLon;
  final double fromHeading;
  final double toLat;
  final double toLon;
  final double toHeading;
  final DateTime start;

  /// Lo que tarda el bus en ir de [from…] a [to…]: lo que tardó en llegar
  /// la fijación ([tramoEntre]). Así el bus no se para entre dos
  /// posiciones ni salta al llegar la siguiente.
  final Duration duration;

  /// La flota simulada manda una posición por segundo.
  static const Duration minimo = Duration(seconds: 1);

  /// Un GPS real manda una cada 5–15 s; más que eso es un bus que se quedó
  /// sin señal un rato, y arrastrarlo minutos sería mentir dónde va.
  static const Duration maximo = Duration(seconds: 15);

  /// El tramo para una fijación capturada en [ahoraMs] tras la de [antesMs]
  /// (milisegundos desde epoch), entre [minimo] y [maximo]. Sin las dos
  /// fechas, o con la nueva más vieja, [minimo].
  static Duration tramoEntre(int? antesMs, int? ahoraMs) {
    if (antesMs == null || ahoraMs == null) return minimo;
    final ms =
        (ahoraMs - antesMs).clamp(minimo.inMilliseconds, maximo.inMilliseconds);
    return Duration(milliseconds: ms);
  }

  /// [tramoEntre] dos posiciones del mismo bus: con la hora del equipo si
  /// las dos la traen y, si no, con la del servidor; las dos son de la
  /// fijación.
  static Duration tramoDe(BusPosition antes, BusPosition ahora) =>
      antes.capturedAt != null && ahora.capturedAt != null
          ? tramoEntre(antes.capturedAt, ahora.capturedAt)
          : tramoEntre(antes.timestamp.millisecondsSinceEpoch,
              ahora.timestamp.millisecondsSinceEpoch);

  bool isFinished(DateTime now) => now.difference(start) >= duration;
}

/// Interpola linealmente lat/lon y el heading por el arco más corto.
(double, double, double) displayOf(BusMotion motion, DateTime now) {
  final t = (now.difference(motion.start).inMilliseconds /
          motion.duration.inMilliseconds)
      .clamp(0.0, 1.0);
  double lerp(double a, double b) => a + (b - a) * t;
  var delta = (motion.toHeading - motion.fromHeading) % 360;
  if (delta > 180) delta -= 360;
  if (delta < -180) delta += 360;
  final heading = (motion.fromHeading + delta * t + 360) % 360;
  return (
    lerp(motion.fromLat, motion.toLat),
    lerp(motion.fromLon, motion.toLon),
    heading,
  );
}
