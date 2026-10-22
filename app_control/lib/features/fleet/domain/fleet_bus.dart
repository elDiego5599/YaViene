class FleetBus {
  const FleetBus({
    required this.busId,
    required this.companyId,
    required this.visible,
    required this.online,
    this.placa = '',
    this.interno = '',
    this.driverName,
    this.routeId,
    this.lat,
    this.lon,
    this.heading,
    this.speedKmh = 0,
    this.capturedAt,
    this.receivedAt,
    this.sequence,
    this.isGhost = false,
    this.enTerminal = false,
  });

  factory FleetBus.fromJson(Map<String, dynamic> json) {
    final routeId = json['routeId'] as String?;
    return FleetBus(
      busId: json['busId'] as String,
      companyId: json['companyId'] as String? ?? '',
      routeId: routeId == null || routeId.isEmpty ? null : routeId,
      placa: json['placa'] as String? ?? '',
      interno: json['interno'] as String? ?? '',
      driverName: json['driverName'] as String?,
      visible: json['visible'] == true,
      online: json['online'] == true,
      lat: (json['lat'] as num?)?.toDouble(),
      lon: (json['lon'] as num?)?.toDouble(),
      heading: (json['heading'] as num?)?.toDouble(),
      speedKmh: (json['speedKmh'] as num?)?.toDouble() ?? 0,
      capturedAt: (json['capturedAt'] as num?)?.toInt(),
      receivedAt: (json['receivedAt'] as num?)?.toInt(),
      sequence: (json['sequence'] as num?)?.toInt(),
      isGhost: json['isGhost'] == true,
      enTerminal: json['enTerminal'] == true,
    );
  }

  final String busId;
  final String companyId;
  final String placa;
  final String interno;
  final String? driverName;
  final String? routeId;
  final bool visible;
  final bool online;
  final double? lat;
  final double? lon;

  /// Grados en [0, 360); null si el bus no lo mandó. Una posición sin rumbo
  /// deja el que había (`copyWith`) en vez de girar el bus hacia el norte.
  final double? heading;
  final double speedKmh;
  final int? capturedAt;
  final int? receivedAt;
  final int? sequence;
  final bool isGhost;
  final bool enTerminal;

  /// Si [otro] se pinta igual en la lista y en la ficha del bus: todo menos
  /// la posición (lat, lon, rumbo, velocidad, horas y secuencia), que solo
  /// pinta el mapa. El dashboard se reconstruye cuando esto cambia y no con
  /// cada `bus:position` (R-27). Un campo nuevo que la lista o la ficha
  /// enseñen tiene que entrar aquí, o la pantalla se queda con el viejo.
  bool mismaFicha(FleetBus otro) =>
      busId == otro.busId &&
      companyId == otro.companyId &&
      placa == otro.placa &&
      interno == otro.interno &&
      driverName == otro.driverName &&
      routeId == otro.routeId &&
      visible == otro.visible &&
      online == otro.online &&
      isGhost == otro.isGhost &&
      enTerminal == otro.enTerminal;

  FleetBus copyWith({
    String? placa,
    String? interno,
    String? driverName,
    String? routeId,
    bool? visible,
    bool? online,
    double? lat,
    double? lon,
    double? heading,
    double? speedKmh,
    int? capturedAt,
    int? receivedAt,
    int? sequence,
    bool? isGhost,
    bool? enTerminal,
    bool clearPosition = false,
  }) {
    return FleetBus(
      busId: busId,
      companyId: companyId,
      placa: placa ?? this.placa,
      interno: interno ?? this.interno,
      driverName: driverName ?? this.driverName,
      routeId: routeId ?? this.routeId,
      visible: visible ?? this.visible,
      online: online ?? this.online,
      lat: clearPosition ? null : lat ?? this.lat,
      lon: clearPosition ? null : lon ?? this.lon,
      heading: heading ?? this.heading,
      speedKmh: speedKmh ?? this.speedKmh,
      capturedAt: clearPosition ? null : capturedAt ?? this.capturedAt,
      receivedAt: clearPosition ? null : receivedAt ?? this.receivedAt,
      sequence: sequence ?? this.sequence,
      isGhost: isGhost ?? this.isGhost,
      enTerminal: enTerminal ?? this.enTerminal,
    );
  }
}
