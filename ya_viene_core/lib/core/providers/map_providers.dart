
import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/bus_position.dart';
import '../models/bus_stop.dart';
import '../models/route_trajectory.dart';


final routeTrajectoryProvider = FutureProvider.autoDispose
    .family<RouteTrajectory, String>((ref, routeId) async {
  await Future.delayed(const Duration(milliseconds: 400));

  return RouteTrajectory(
    routeId: routeId,
    routeName: 'Ruta 1 Ida — Centro/Soledad',
    points: const [
      GeoPoint(lat: 10.9200, lon: -74.7800),
      GeoPoint(lat: 10.9320, lon: -74.7870),
      GeoPoint(lat: 10.9440, lon: -74.7920),
      GeoPoint(lat: 10.9560, lon: -74.7975),
      GeoPoint(lat: 10.9650, lon: -74.8010),
      GeoPoint(lat: 10.9740, lon: -74.8040),
      GeoPoint(lat: 10.9840, lon: -74.8060),
      GeoPoint(lat: 10.9930, lon: -74.8070),
      GeoPoint(lat: 11.0020, lon: -74.8075),
      GeoPoint(lat: 11.0120, lon: -74.8080),
    ],
  );
});


final busStopsProvider =
    FutureProvider.autoDispose.family<List<BusStop>, String>(
  (ref, routeId) async {
    await Future.delayed(const Duration(milliseconds: 300));

    return const [
      BusStop(
        id: 'P-001',
        name: 'Terminal Soledad',
        tipo: BusStopType.fija,
        lat: 10.9200,
        lon: -74.7800,
        orden: 1,
      ),
      BusStop(
        id: 'P-005',
        name: 'Calle 30 con Carrera 46',
        tipo: BusStopType.fija,
        lat: 10.9650,
        lon: -74.8010,
        orden: 5,
      ),

      BusStop(
        id: 'P-003',
        name: 'Zona Mercado La Pascuala',
        tipo: BusStopType.informal,
        lat: 10.9440,
        lon: -74.7920,
        orden: 3,
        radioInfluenciaM: 120,
      ),
      BusStop(
        id: 'P-008',
        name: 'Zona El Prado / Hotel El Prado',
        tipo: BusStopType.informal,
        lat: 10.9930,
        lon: -74.8070,
        orden: 8,
        radioInfluenciaM: 80,
      ),
    ];
  },
);


final movingBusProvider = StreamProvider.autoDispose<BusPosition>((ref) async* {
  const waypoints = [
    (lat: 10.9200, lon: -74.7800),
    (lat: 10.9320, lon: -74.7870),
    (lat: 10.9440, lon: -74.7920),
    (lat: 10.9560, lon: -74.7975),
    (lat: 10.9650, lon: -74.8010),
    (lat: 10.9740, lon: -74.8040),
    (lat: 10.9840, lon: -74.8060),
    (lat: 10.9930, lon: -74.8070),
    (lat: 11.0020, lon: -74.8075),
    (lat: 11.0120, lon: -74.8080),
  ];

  int tick = 0;
  const stepsPerSegment = 10;

  while (true) {
    await Future.delayed(const Duration(seconds: 3));

    final segmentIndex = (tick ~/ stepsPerSegment) % (waypoints.length - 1);
    final t = (tick % stepsPerSegment) / stepsPerSegment;

    final from = waypoints[segmentIndex];
    final to = waypoints[(segmentIndex + 1) % waypoints.length];

    final lat = from.lat + (to.lat - from.lat) * t;
    final lon = from.lon + (to.lon - from.lon) * t;

    final dLat = to.lat - from.lat;
    final dLon = to.lon - from.lon;
    final heading = (math.atan2(dLon, dLat) * 180 / math.pi + 360) % 360;

    final isGhost = tick == 15;
    final timestamp = isGhost
        ? DateTime.now().subtract(const Duration(seconds: 95))
        : DateTime.now();

    yield BusPosition(
      busId: 'B-001',
      routeId: 'R-101',
      lat: lat,
      lon: lon,
      heading: heading,
      speedKmh: 35 + (tick % 10).toDouble(),
      timestamp: timestamp,
      isGhostBus: isGhost,
    );

    tick++;
  }
});
