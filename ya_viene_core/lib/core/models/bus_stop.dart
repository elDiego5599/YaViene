import 'package:equatable/equatable.dart';

enum BusStopType {
  fija,

  informal,
}

class BusStop extends Equatable {
  final String id;

  final String name;

  final BusStopType tipo;

  final double lat;

  final double lon;

  final double? radioInfluenciaM;

  final int orden;

  const BusStop({
    required this.id,
    required this.name,
    required this.tipo,
    required this.lat,
    required this.lon,
    required this.orden,
    this.radioInfluenciaM,
  }) : assert(
          tipo == BusStopType.fija || radioInfluenciaM != null,
          'Las paradas informales deben tener radioInfluenciaM definido.',
        );

  factory BusStop.fromJson(Map<String, dynamic> json) {
    return BusStop(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      tipo: BusStopType.values.firstWhere(
        (e) => e.name == json['tipo'],
        orElse: () => BusStopType.fija,
      ),
      lat: (json['lat'] as num?)?.toDouble() ?? 0.0,
      lon: (json['lon'] as num?)?.toDouble() ?? 0.0,
      orden: (json['orden'] as num?)?.toInt() ?? 0,
      radioInfluenciaM: (json['radioInfluenciaM'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'tipo': tipo.name,
      'lat': lat,
      'lon': lon,
      'orden': orden,
      'radioInfluenciaM': radioInfluenciaM,
    };
  }

  BusStop copyWith({
    String? id,
    String? name,
    BusStopType? tipo,
    double? lat,
    double? lon,
    int? orden,
    double? radioInfluenciaM,
  }) {
    return BusStop(
      id: id ?? this.id,
      name: name ?? this.name,
      tipo: tipo ?? this.tipo,
      lat: lat ?? this.lat,
      lon: lon ?? this.lon,
      orden: orden ?? this.orden,
      radioInfluenciaM: radioInfluenciaM ?? this.radioInfluenciaM,
    );
  }

  Map<String, dynamic> toGeoJsonFeature() {
    return {
      'type': 'Feature',
      'geometry': {
        'type': 'Point',
        'coordinates': [lon, lat],
      },
      'properties': {
        'id': id,
        'name': name,
        'tipo': tipo.name,
        'radio_m': radioInfluenciaM ?? 0,
        'orden': orden,
      },
    };
  }

  @override
  List<Object?> get props =>
      [id, name, lat, lon, tipo, orden, radioInfluenciaM];
}
