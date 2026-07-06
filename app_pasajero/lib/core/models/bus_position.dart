/// =============================================================================
/// MODELOS DE DOMINIO
/// Clases Dart puras (sin dependencias de Flutter) que representan
/// las entidades del negocio. Extienden Equatable para comparación por valor.
/// =============================================================================

import 'package:equatable/equatable.dart';

// ── BusPosition ──────────────────────────────────────────────────────────────

/// Representa la posición en tiempo real de un bus en el mapa.
///
/// [isGhostBus]: true cuando la última posición tiene más de 90 segundos.
/// En ese caso, la UI debe renderizar el ícono en [AppColors.busGhost].
class BusPosition extends Equatable {
  final String busId;
  final String routeId;
  final double lat;
  final double lon;
  final double heading;       // 0-360°, para rotar el ícono
  final double speedKmh;
  final DateTime timestamp;
  final bool isGhostBus;

  const BusPosition({
    required this.busId,
    required this.routeId,
    required this.lat,
    required this.lon,
    required this.heading,
    required this.speedKmh,
    required this.timestamp,
    required this.isGhostBus,
  });

  /// Los segundos transcurridos desde la última posición recibida.
  int get secondsSinceUpdate =>
      DateTime.now().difference(timestamp).inSeconds;

  /// Regla de negocio: si pasaron más de 90s, el bus es "fantasma".
  bool get shouldShowAsGhost => secondsSinceUpdate > 90;

  @override
  List<Object?> get props => [busId, routeId, lat, lon, heading, timestamp];
}
