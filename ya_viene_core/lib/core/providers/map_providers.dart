import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/bus_position.dart';
import '../models/bus_stop.dart';
import '../models/route_trajectory.dart';

final appLifecycleProvider = StateProvider.autoDispose<AppLifecycleState>(
  (ref) => AppLifecycleState.resumed,
);

/// Datos de las rutas reales (recorridos y paradas), generados desde los
/// KMZ de Sobusa con `convert-rutas.mjs`. Las paradas quedan vacías para la
/// mayoría de rutas: los buses en Barranquilla no tienen paradas fijas.
class RutaSobusa {
  final String routeId;
  final String name;
  final String? terminalA;
  final String? terminalB;
  final double lengthKm;
  final List<GeoPoint> waypoints;
  final List<BusStop> paradas;

  const RutaSobusa({
    required this.routeId,
    required this.name,
    required this.terminalA,
    required this.terminalB,
    required this.lengthKm,
    required this.waypoints,
    required this.paradas,
  });

  factory RutaSobusa.fromJson(Map<String, dynamic> json) {
    return RutaSobusa(
      routeId: json['routeId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      terminalA: json['terminalA'] as String?,
      terminalB: json['terminalB'] as String?,
      lengthKm: (json['lengthKm'] as num?)?.toDouble() ?? 0,
      waypoints: (json['waypoints'] as List<dynamic>?)
              ?.map((e) => GeoPoint.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      paradas: (json['paradas'] as List<dynamic>?)
              ?.map((e) => BusStop.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }
}

/// Carga `rutas.json` (asset del app_pasajero) con los recorridos reales.
final rutasSobusaProvider = FutureProvider.autoDispose<List<RutaSobusa>>(
  (ref) async {
    try {
      final raw = await rootBundle.loadString('assets/data/rutas.json');
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final rutas = (decoded['rutas'] as List<dynamic>? ?? const [])
          .map((e) => RutaSobusa.fromJson(e as Map<String, dynamic>))
          .toList();
      if (rutas.isEmpty) {
        debugPrint('[rutas] rutas.json vacío o sin rutas');
      }
      return rutas;
    } catch (e) {
      debugPrint('[rutas] no se pudo cargar rutas.json: $e');
      return const [];
    }
  },
);

/// Geometría del recorrido de una ruta (línea azul en el mapa).
///
/// El recorrido sale de un asset local, y eso tiene fecha de caducidad: hoy
/// las rutas del catálogo son las seis de Sobusa, convertidas de sus KMZ, y
/// una ruta que una empresa dé de alta desde el panel de flota no aparece
/// aquí — el backend guarda rutas, no recorridos. Cuando eso pase, la ruta
/// existe y sus buses se ven, pero su línea no se dibuja.
///
/// La app está preparada para ese caso y lo trata como "no se sabe", nunca
/// como error: sin geometría no se pinta línea, la comprobación de "esta
/// ruta no pasa cerca de ti" se desactiva sola en vez de bloquear el aviso
/// (`routeDistanceToUserProvider`, con sus pruebas en `route_reach_test`), y
/// la cámara encuadra los buses en lugar del recorrido
/// (`fitLiveViewport`). Degradar es correcto; lo que no hay es aviso.
///
/// El día que las rutas dejen de ser un puñado fijo, el recorrido tiene que
/// viajar con el catálogo desde el backend y este proveedor pasa a leerlo de
/// ahí, con el asset como respaldo sin red.
final routeTrajectoryProvider = FutureProvider.autoDispose
    .family<RouteTrajectory, String>((ref, routeId) async {
  final rutas = await ref.watch(rutasSobusaProvider.future);
  for (final ruta in rutas) {
    if (ruta.routeId == routeId) {
      return RouteTrajectory(
        routeId: ruta.routeId,
        routeName: ruta.name,
        points: ruta.waypoints,
      );
    }
  }
  debugPrint('[rutas] ruta $routeId no encontrada en rutas.json');
  return RouteTrajectory(routeId: routeId, routeName: '', points: const []);
});

/// Paradas de una ruta (vacías en la mayoría: buses sin paradas fijas).
final busStopsProvider =
    FutureProvider.autoDispose.family<List<BusStop>, String>(
  (ref, routeId) async {
    final rutas = await ref.watch(rutasSobusaProvider.future);
    for (final ruta in rutas) {
      if (ruta.routeId == routeId) return ruta.paradas;
    }
    return const <BusStop>[];
  },
);

final movingBusProvider = StreamProvider.autoDispose<BusPosition>((ref) {
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

  final controller = StreamController<BusPosition>();
  int tick = 0;
  const stepsPerSegment = 10;
  Timer? timer;

  void tickCallback() {
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

    controller.add(BusPosition(
      busId: 'B-001',
      routeId: 'R-101',
      lat: lat,
      lon: lon,
      heading: heading,
      speedKmh: 35 + (tick % 10).toDouble(),
      timestamp: timestamp,
      isGhostBus: isGhost,
    ));
    tick++;
  }

  ref.listen(appLifecycleProvider, (_, state) {
    if (state == AppLifecycleState.resumed) {
      timer ??=
          Timer.periodic(const Duration(seconds: 3), (_) => tickCallback());
    } else {
      timer?.cancel();
      timer = null;
    }
  });

  ref.onDispose(() {
    timer?.cancel();
    controller.close();
  });

  timer = Timer.periodic(const Duration(seconds: 3), (_) => tickCallback());

  return controller.stream;
});
