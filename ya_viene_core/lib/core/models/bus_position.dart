import 'package:equatable/equatable.dart';

class BusPosition extends Equatable {
  final String busId;
  final String routeId;
  final double lat;
  final double lon;
  final double heading;
  final double speedKmh;

  /// Sentido de marcha reportado por el bus: "ida" o "venida" (null si el
  /// dispositivo aún no lo reporta; se asume ida).
  final String? sentido;
  final DateTime timestamp;
  final bool isGhostBus;
  final int? sequence;

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
  });

  factory BusPosition.fromJson(Map<String, dynamic> json) {
    final rawTimestamp = json['timestamp'];
    final parsedTimestamp = rawTimestamp is num
        ? DateTime.fromMillisecondsSinceEpoch(rawTimestamp.toInt())
        : DateTime.tryParse(rawTimestamp as String? ?? '') ?? DateTime.now();

    return BusPosition(
      busId: json['busId'] as String? ?? '',
      routeId: json['routeId'] as String? ?? '',
      lat: (json['lat'] as num?)?.toDouble() ?? 0.0,
      lon: (json['lon'] as num?)?.toDouble() ?? 0.0,
      heading: (json['heading'] as num?)?.toDouble() ?? 0.0,
      speedKmh: (json['speedKmh'] as num?)?.toDouble() ?? 0.0,
      sentido: json['sentido'] as String?,
      timestamp: parsedTimestamp,
      isGhostBus:
          (json['isGhostBus'] as bool?) ?? (json['isGhost'] as bool?) ?? false,
      sequence: (json['sequence'] as num?)?.toInt(),
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
      ];
}
