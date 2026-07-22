
import 'package:equatable/equatable.dart';

class GeoPoint extends Equatable {
  final double lat;
  final double lon;

  const GeoPoint({required this.lat, required this.lon});

  List<double> toGeoJsonCoordinate() => [lon, lat];

  @override
  List<Object?> get props => [lat, lon];
}

class RouteTrajectory extends Equatable {
  final String routeId;

  final String routeName;

  final List<GeoPoint> points;

  const RouteTrajectory({
    required this.routeId,
    required this.routeName,
    required this.points,
  });

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

  GeoPoint get center {
    if (points.isEmpty) return const GeoPoint(lat: 11.0041, lon: -74.8070);
    final midIndex = points.length ~/ 2;
    return points[midIndex];
  }

  @override
  List<Object?> get props => [routeId, points];
}
