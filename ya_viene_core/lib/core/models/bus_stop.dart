/// =============================================================================
/// MODELO: BusStop (Parada de Bus)
///
/// Implementa el Modelo Dual de Paradas descrito en el Plan:
///
///   - tipo == 'fija'    → Estación formal. Se dibuja como un marcador sólido
///                         puntual en el mapa (CircleLayer con radio fijo ~8px).
///
///   - tipo == 'informal' → Zona de abordaje donde los pasajeros "sacan la mano".
///                          Se dibuja como un halo/círculo semitransparente usando
///                          el campo [radioInfluenciaM] para escalar el radio del
///                          FillLayer en metros reales sobre el mapa.
///
/// Ambos tipos comparten los campos base de nombre y ubicación.
/// El campo [radioInfluenciaM] es irrelevante (null) para paradas fijas.
/// =============================================================================

import 'package:equatable/equatable.dart';

/// Tipo de parada de transporte público.
enum BusStopType {
  /// Parada formal con señalización física. Marcador sólido en el mapa.
  fija,

  /// Zona informal de abordaje. Círculo semitransparente (halo) en el mapa.
  /// Representa el área donde los pasajeros esperan para "sacar la mano".
  informal,
}

class BusStop extends Equatable {
  /// Identificador único de la parada en la base de datos.
  final String id;

  /// Nombre legible por el usuario (ej: "Terminal Sur", "Cra 46 con Calle 72").
  final String name;

  /// Tipo de parada que determina cómo se renderiza en el mapa.
  final BusStopType tipo;

  /// Latitud del punto central de la parada.
  final double lat;

  /// Longitud del punto central de la parada.
  final double lon;

  /// Radio de influencia en metros. SOLO aplica cuando [tipo] == informal.
  /// Define el radio del círculo semitransparente (halo) de la zona de abordaje.
  /// Es null para paradas fijas.
  final double? radioInfluenciaM;

  /// Orden de la parada dentro de la ruta (para secuenciarlas).
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

  /// Construye el objeto GeoJSON Feature para esta parada.
  /// Se pasa directamente al source de Mapbox sin crear widgets de Flutter.
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
        'tipo': tipo.name,   // 'fija' o 'informal'
        'radio_m': radioInfluenciaM ?? 0,
        'orden': orden,
      },
    };
  }

  @override
  List<Object?> get props => [id, lat, lon, tipo, orden];
}
