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
  });

  final double fromLat;
  final double fromLon;
  final double fromHeading;
  final double toLat;
  final double toLon;
  final double toHeading;
  final DateTime start;

  /// Duración del tramo: con fixes cada ~1s, un tramo de 1s da movimiento
  /// continuo y suave (sin esperas ni saltos).
  static const Duration duration = Duration(milliseconds: 1000);

  bool isFinished(DateTime now) => now.difference(start) >= duration;
}

/// Interpola linealmente lat/lon y el heading por el arco más corto.
(double, double, double) displayOf(BusMotion motion, DateTime now) {
  final t = (now.difference(motion.start).inMilliseconds /
          BusMotion.duration.inMilliseconds)
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
