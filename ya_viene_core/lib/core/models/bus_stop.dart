
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
  List<Object?> get props => [id, lat, lon, tipo, orden];
}
