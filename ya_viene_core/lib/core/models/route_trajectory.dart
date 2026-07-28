
import 'package:equatable/equatable.dart';

class GeoPoint extends Equatable {
  final double lat;
  final double lon;

  const GeoPoint({required this.lat, required this.lon});

  factory GeoPoint.fromJson(Map<String, dynamic> json) {
    return GeoPoint(
      lat: (json['lat'] as num?)?.toDouble() ?? 0.0,
      lon: (json['lon'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {'lat': lat, 'lon': lon};

  GeoPoint copyWith({double? lat, double? lon}) {
    return GeoPoint(
      lat: lat ?? this.lat,
      lon: lon ?? this.lon,
    );
  }

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

  factory RouteTrajectory.fromJson(Map<String, dynamic> json) {
    return RouteTrajectory(
      routeId: json['routeId'] as String? ?? '',
      routeName: json['routeName'] as String? ?? '',
      points: (json['points'] as List<dynamic>?)
              ?.map((e) => GeoPoint.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'routeId': routeId,
      'routeName': routeName,
      'points': points.map((p) => p.toJson()).toList(),
    };
  }

  RouteTrajectory copyWith({
    String? routeId,
    String? routeName,
    List<GeoPoint>? points,
  }) {
    return RouteTrajectory(
      routeId: routeId ?? this.routeId,
      routeName: routeName ?? this.routeName,
      points: points ?? this.points,
    );
  }

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
  List<Object?> get props => [routeId, routeName, points];
}
