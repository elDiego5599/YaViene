/// =============================================================================
/// MODELO: RouteTrajectory (Trayectoria de Ruta)
///
/// Encapsula el LineString geoespacial de una ruta de transporte.
/// En el backend, este dato viene de la columna PostGIS `trazado` (LineString)
/// y se serializa como GeoJSON para enviarlo al cliente vía HTTP REST.
///
/// El widget de mapa usa [toGeoJsonSource] para alimentar directamente
/// al GeoJsonSource de Mapbox, sin pasar por widgets de Flutter.
/// =============================================================================

import 'package:equatable/equatable.dart';

/// Un punto geográfico dentro de la trayectoria de la ruta.
class GeoPoint extends Equatable {
  final double lat;
  final double lon;

  const GeoPoint({required this.lat, required this.lon});

  /// GeoJSON usa [longitude, latitude] (orden inverso al convencional).
  List<double> toGeoJsonCoordinate() => [lon, lat];

  @override
  List<Object?> get props => [lat, lon];
}

class RouteTrajectory extends Equatable {
  /// ID de la ruta en la base de datos.
  final String routeId;

  /// Nombre descriptivo (ej: "Ruta 1 Ida — Centro/Soledad").
  final String routeName;

  /// Lista ordenada de puntos que definen el trazado de la ruta.
  /// Corresponde al LineString de PostGIS.
  final List<GeoPoint> points;

  const RouteTrajectory({
    required this.routeId,
    required this.routeName,
    required this.points,
  });

  /// Construye el GeoJSON Feature del LineString de la ruta.
  /// Se pasa directamente al GeoJsonSource de Mapbox.
  Map<String, dynamic> toGeoJsonFeatureCollection() {
    return {
      'type': 'FeatureCollection',
      'features': [
        {
          'type': 'Feature',
          'geometry': {
            'type': 'LineString',
            'coordinates': points
                .map((p) => p.toGeoJsonCoordinate())
                .toList(),
          },
          'properties': {
            'routeId': routeId,
            'routeName': routeName,
          },
        }
      ],
    };
  }

  /// Centro aproximado de la ruta — usado para el cameraPosition inicial del mapa.
  GeoPoint get center {
    if (points.isEmpty) return const GeoPoint(lat: 11.0041, lon: -74.8070);
    final midIndex = points.length ~/ 2;
    return points[midIndex];
  }

  @override
  List<Object?> get props => [routeId, points];
}
