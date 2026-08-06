class FleetBus {
  const FleetBus({
    required this.busId,
    required this.companyId,
    required this.visible,
    required this.online,
    this.routeId,
    this.lat,
    this.lon,
    this.heading = 0,
    this.speedKmh = 0,
    this.capturedAt,
    this.receivedAt,
    this.sequence,
    this.isGhost = false,
  });

  factory FleetBus.fromJson(Map<String, dynamic> json) {
    return FleetBus(
      busId: json['busId'] as String,
      companyId: json['companyId'] as String? ?? '',
      routeId: json['routeId'] as String?,
      visible: json['visible'] == true,
      online: json['online'] == true,
      lat: (json['lat'] as num?)?.toDouble(),
      lon: (json['lon'] as num?)?.toDouble(),
      heading: (json['heading'] as num?)?.toDouble() ?? 0,
      speedKmh: (json['speedKmh'] as num?)?.toDouble() ?? 0,
      capturedAt: (json['capturedAt'] as num?)?.toInt(),
      receivedAt: (json['receivedAt'] as num?)?.toInt(),
      sequence: (json['sequence'] as num?)?.toInt(),
      isGhost: json['isGhost'] == true,
    );
  }

  final String busId;
  final String companyId;
  final String? routeId;
  final bool visible;
  final bool online;
  final double? lat;
  final double? lon;
  final double heading;
  final double speedKmh;
  final int? capturedAt;
  final int? receivedAt;
  final int? sequence;
  final bool isGhost;

  FleetBus copyWith({
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
    bool clearPosition = false,
  }) {
    return FleetBus(
      busId: busId,
      companyId: companyId,
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
    );
  }
}