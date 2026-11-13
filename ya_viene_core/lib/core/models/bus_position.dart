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

  /// Es un bus de la flota de ejemplo, no uno de verdad: lo que se calcule
  /// con él (la hora de llegada, D24) lleva la etiqueta «Simulación».
  final bool simulado;

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
    this.simulado = false,
  });

  /// Lee una posición que llega por la red, o null si no se puede creer.
  ///
  /// Es la única puerta de entrada: un evento malformado no tumba a quien
  /// escucha el socket, y lo que no pasa aquí no llega al mapa. Rechaza:
  ///
  /// - identidad o coordenada ausentes, o fuera de rango: rellenar con ceros
  ///   ponía el bus en (0, 0), en el golfo de Guinea;
  /// - rumbo o velocidad no finitos, que giran el icono a ninguna parte;
  /// - una fecha que falta o no se entiende: volverla «ahora» hacía pasar
  ///   por recién reportado un bus con horas de silencio;
  /// - una fecha del futuro más allá de la holgura del reloj;
  /// - una posición en vivo más vieja de lo que el servidor da por viva. Las
  ///   de un bus sin señal no tienen tope: su fecha vieja es justo lo que se
  ///   enseña («Sin señal desde hace 2 h»).
  static BusPosition? tryParse(Map<String, dynamic> json) {
    try {
      return _leer(json);
    } on FormatException {
      return null;
    } on TypeError {
      // Un campo con el tipo equivocado (`lat` como texto, `busId` como
      // número) lanza al hacer el `as`: tampoco es una posición.
      return null;
    }
  }

  /// El `timestamp` lo pone el servidor al recibir la posición, y el reloj
  /// del teléfono no es el suyo: puede ir unos minutos corrido si alguien lo
  /// puso a mano. Diez minutos de holgura cubren eso sin dejar pasar una
  /// fecha que no tiene sentido.
  static const Duration _holguraDeReloj = Duration(minutes: 10);

  /// Lo más vieja que puede llegar una posición que el servidor todavía da
  /// por viva: a los 5 min sin publicar el bus pasa a «sin señal»
  /// (`GHOST_MS` en el backend) y el barrido que lo marca corre cada 10 s.
  static const Duration _vidaEnVivo = Duration(minutes: 5, seconds: 10);

  static BusPosition _leer(Map<String, dynamic> json) {
    final lat = (json['lat'] as num?)?.toDouble();
    final lon = (json['lon'] as num?)?.toDouble();
    if (lat == null || lon == null) {
      throw const FormatException('posición sin lat/lon');
    }
    final busId = (json['busId'] as String?)?.trim();
    final routeId = (json['routeId'] as String?)?.trim();
    if (busId == null || busId.isEmpty || routeId == null || routeId.isEmpty) {
      throw const FormatException('posición sin busId/routeId');
    }
    if (!lat.isFinite ||
        !lon.isFinite ||
        lat < -90 ||
        lat > 90 ||
        lon < -180 ||
        lon > 180) {
      throw const FormatException('posición fuera de rango');
    }
    final heading = (json['heading'] as num?)?.toDouble();
    final speedKmh = (json['speedKmh'] as num?)?.toDouble() ?? 0.0;
    if ((heading != null && !heading.isFinite) || !speedKmh.isFinite) {
      throw const FormatException('rumbo o velocidad no finitos');
    }
    final timestamp = DateTime.tryParse(json['timestamp'] as String? ?? '');
    if (timestamp == null) {
      throw const FormatException('posición sin fecha válida');
    }
    final isGhost = json['isGhost'] as bool? ?? false;
    final ahora = DateTime.now();
    if (timestamp.difference(ahora) > _holguraDeReloj) {
      throw const FormatException('posición con fecha del futuro');
    }
    if (!isGhost &&
        ahora.difference(timestamp) > _vidaEnVivo + _holguraDeReloj) {
      throw const FormatException('posición en vivo demasiado vieja');
    }
    return BusPosition(
      busId: busId,
      routeId: routeId,
      lat: lat,
      lon: lon,
      // Sin rumbo queda null: rellenarlo con 0 giraba el bus hacia el norte.
      heading: heading,
      speedKmh: speedKmh,
      sentido: json['sentido'] as String?,
      timestamp: timestamp,
      isGhostBus: isGhost,
      // La captura del equipo es lo que ordena las posiciones de un bus
      // ([esMasNueva]); sin leerla la última en llegar ganaba.
      sequence: (json['sequence'] as num?)?.toInt(),
      capturedAt: (json['capturedAt'] as num?)?.toInt(),
      simulado: json['simulado'] as bool? ?? false,
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
      'simulado': simulado,
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
    bool? simulado,
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
      simulado: simulado ?? this.simulado,
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
        simulado,
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
