import 'package:equatable/equatable.dart';

class BusPosition extends Equatable {
  final String busId;
  final String routeId;
  final double lat;
  final double lon;

  /// Grados en [0, 360); null si el bus no lo mandó. No se rellena con 0,
  /// porque 0 es el norte.
  final double? heading;
  final double speedKmh;

  /// Sentido de marcha reportado por el bus: "ida" o "venida" (null si el
  /// dispositivo aún no lo reporta; se asume ida).
  final String? sentido;
  final DateTime timestamp;
  final bool isGhostBus;
  final int? sequence;

  /// Cuándo capturó el equipo del bus esta posición, en milisegundos desde
  /// epoch; null si el servidor no la manda. Es lo que ordena las posiciones
  /// de un bus ([esMasNueva]): `sequence` vuelve a empezar con cada sesión del
  /// equipo.
  final int? capturedAt;

  const BusPosition({
    required this.busId,
    required this.routeId,
    required this.lat,
    required this.lon,
    required this.heading,
    required this.speedKmh,
    required this.timestamp,
    required this.isGhostBus,
    this.sentido,
    this.sequence,
    this.capturedAt,
  });

  /// Lanza [FormatException] si al JSON le falta identidad o coordenada.
  /// Antes rellenaba con ceros y un mensaje sin `lat` producía un bus en
  /// (0, 0) —golfo de Guinea— que el mapa pintaba tan campante. Quien lea de
  /// la red debe envolver esto: `safeBusPosition` en el pasajero ya lo hace.
  factory BusPosition.fromJson(Map<String, dynamic> json) {
    final rawTimestamp = json['timestamp'];
    final parsedTimestamp = rawTimestamp is num
        ? DateTime.fromMillisecondsSinceEpoch(rawTimestamp.toInt())
        : DateTime.tryParse(rawTimestamp as String? ?? '') ?? DateTime.now();

    final busId = (json['busId'] as String?)?.trim();
    final routeId = (json['routeId'] as String?)?.trim();
    if (busId == null || busId.isEmpty || routeId == null || routeId.isEmpty) {
      throw const FormatException('posición sin busId/routeId');
    }
    final lat = (json['lat'] as num?)?.toDouble();
    final lon = (json['lon'] as num?)?.toDouble();
    if (lat == null || lon == null) {
      throw const FormatException('posición sin lat/lon');
    }
    if (!lat.isFinite ||
        !lon.isFinite ||
        lat < -90 ||
        lat > 90 ||
        lon < -180 ||
        lon > 180) {
      throw const FormatException('posición fuera de rango');
    }

    return BusPosition(
      busId: busId,
      routeId: routeId,
      lat: lat,
      lon: lon,
      heading: (json['heading'] as num?)?.toDouble(),
      speedKmh: (json['speedKmh'] as num?)?.toDouble() ?? 0.0,
      sentido: json['sentido'] as String?,
      timestamp: parsedTimestamp,
      isGhostBus:
          (json['isGhostBus'] as bool?) ?? (json['isGhost'] as bool?) ?? false,
      sequence: (json['sequence'] as num?)?.toInt(),
      capturedAt: (json['capturedAt'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'busId': busId,
      'routeId': routeId,
      'lat': lat,
      'lon': lon,
      'heading': heading,
      'speedKmh': speedKmh,
      'sentido': sentido,
      'timestamp': timestamp.toIso8601String(),
      'isGhost': isGhostBus,
      'sequence': sequence,
      'capturedAt': capturedAt,
    };
  }

  BusPosition copyWith({
    String? busId,
    String? routeId,
    double? lat,
    double? lon,
    double? heading,
    double? speedKmh,
    String? sentido,
    DateTime? timestamp,
    bool? isGhostBus,
    int? sequence,
    int? capturedAt,
  }) {
    return BusPosition(
      busId: busId ?? this.busId,
      routeId: routeId ?? this.routeId,
      lat: lat ?? this.lat,
      lon: lon ?? this.lon,
      heading: heading ?? this.heading,
      speedKmh: speedKmh ?? this.speedKmh,
      sentido: sentido ?? this.sentido,
      timestamp: timestamp ?? this.timestamp,
      isGhostBus: isGhostBus ?? this.isGhostBus,
      sequence: sequence ?? this.sequence,
      capturedAt: capturedAt ?? this.capturedAt,
    );
  }

  @override
  List<Object?> get props => [
        busId,
        routeId,
        lat,
        lon,
        heading,
        speedKmh,
        sentido,
        timestamp,
        isGhostBus,
        sequence,
        capturedAt,
      ];
}

/// La captura del equipo manda: es monotónica por bus aunque cambie la sesión.
///
/// Dice si una posición de un bus puede ocupar el lugar de la que ya se tiene
/// de él. Los mensajes no llegan en orden —el socket reconecta, el REST vuelve
/// tarde, el respaldo va atrás— y antes la última en llegar ganaba siempre.
/// Sin captura en alguna de las dos no hay con qué comparar y pasa la nueva.
/// Con la misma captura es el mismo punto: solo pasa si cambia el estado de
/// fantasma. Pasajero y panel usan esta misma regla.
bool esMasNueva({
  required int? capturaNueva,
  required int? capturaPrevia,
  required bool fantasmaNuevo,
  required bool fantasmaPrevio,
}) {
  if (capturaPrevia == null || capturaNueva == null) return true;
  if (capturaNueva != capturaPrevia) return capturaNueva > capturaPrevia;
  return fantasmaNuevo != fantasmaPrevio; // mismo punto: solo cambia el estado
}
