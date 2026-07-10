/// =============================================================================
/// PROVIDERS DE MAPA (Mock para Prueba de Rendimiento)
///
/// Simula datos reales del backend para poder:
///   1. Validar la integración de Mapbox antes de tener el WebSocket real.
///   2. Confirmar que el marcador del bus es el ÚNICO widget que se redibuja
///      por tick — el mapa, las polilíneas y las paradas deben permanecer
///      estáticos (verificar con Flutter DevTools > Widget Rebuild Stats).
///
/// Cuando se integre el WebSocket real (MVP 1), SOLO se cambia la
/// implementación interna del [movingBusProvider]. La UI no cambia.
/// =============================================================================

import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/bus_position.dart';
import '../models/bus_stop.dart';
import '../models/route_trajectory.dart';

// =============================================================================
// PROVIDER 1: Trayectoria de la Ruta (dato estático — se carga una vez)
// =============================================================================

/// FutureProvider que devuelve la trayectoria de la ruta seleccionada.
/// Los 10 puntos siguen un corredor ficticio en el norte de Barranquilla,
/// representando el tramo Soledad → Centro.
final routeTrajectoryProvider =
    FutureProvider.autoDispose.family<RouteTrajectory, String>(
  (ref, routeId) async {
    // Simula latencia de red (el LineString viene de PostGIS via REST)
    await Future.delayed(const Duration(milliseconds: 400));

    return RouteTrajectory(
      routeId: routeId,
      routeName: 'Ruta 1 Ida — Centro/Soledad',
      points: const [
        GeoPoint(lat: 10.9200, lon: -74.7800), // Punto 1: Soledad
        GeoPoint(lat: 10.9320, lon: -74.7870), // Punto 2
        GeoPoint(lat: 10.9440, lon: -74.7920), // Punto 3
        GeoPoint(lat: 10.9560, lon: -74.7975), // Punto 4
        GeoPoint(lat: 10.9650, lon: -74.8010), // Punto 5: Calle 30
        GeoPoint(lat: 10.9740, lon: -74.8040), // Punto 6
        GeoPoint(lat: 10.9840, lon: -74.8060), // Punto 7: Murillo
        GeoPoint(lat: 10.9930, lon: -74.8070), // Punto 8
        GeoPoint(lat: 11.0020, lon: -74.8075), // Punto 9: El Prado
        GeoPoint(lat: 11.0120, lon: -74.8080), // Punto 10: Centro
      ],
    );
  },
);

// =============================================================================
// PROVIDER 2: Paradas de la Ruta (dato estático — se carga una vez)
// =============================================================================

/// FutureProvider con las 4 paradas de prueba:
///   - 2 paradas fijas (marcador sólido)
///   - 2 paradas informales (halo semitransparente con radio en metros)
final busStopsProvider =
    FutureProvider.autoDispose.family<List<BusStop>, String>(
  (ref, routeId) async {
    await Future.delayed(const Duration(milliseconds: 300));

    return const [
      // ── Paradas Fijas ──────────────────────────────────────────────────────
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

      // ── Paradas Informales (zonas de abordaje "sacar la mano") ─────────────
      BusStop(
        id: 'P-003',
        name: 'Zona Mercado La Pascuala',
        tipo: BusStopType.informal,
        lat: 10.9440,
        lon: -74.7920,
        orden: 3,
        radioInfluenciaM: 120, // 120 metros de radio de influencia
      ),
      BusStop(
        id: 'P-008',
        name: 'Zona El Prado / Hotel El Prado',
        tipo: BusStopType.informal,
        lat: 10.9930,
        lon: -74.8070,
        orden: 8,
        radioInfluenciaM: 80, // 80 metros de radio de influencia
      ),
    ];
  },
);

// =============================================================================
// PROVIDER 3: Bus en Movimiento (Stream — emite cada segundo)
//
// ARQUITECTURA DE AISLAMIENTO DE RENDER:
//   Este provider emite una nueva [BusPosition] cada segundo.
//   El widget [MapWidget] observa este provider con un ref.listen() —
//   NO con ref.watch() — para actualizar solo el GeoJsonSource de Mapbox
//   sin reconstruir ningún widget de Flutter.
//
//   Flujo: Stream tick → ref.listen → mapboxMap.style.setStyleSourceProperty()
//   → Motor Mapbox redibuja SOLO el marcador del bus en la GPU.
//   → El árbol de widgets Flutter permanece intacto.
// =============================================================================

/// StreamProvider que simula un bus moviendose a lo largo de la ruta,
/// actualizado cada segundo. Emite una [BusPosition] con:
///   - lat/lon interpolados a lo largo de los 10 puntos de la ruta.
///   - heading calculado dinámicamente (ángulo entre punto actual y siguiente).
///   - El tick 15 simula señal débil (isGhostBus: true) para probar el ícono gris.
final movingBusProvider = StreamProvider.autoDispose<BusPosition>((ref) async* {
  // Los 10 puntos del corredor (deben coincidir con routeTrajectoryProvider)
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
  int waypointIndex = 0;
  // Sub-pasos de interpolación entre cada par de waypoints
  const stepsPerSegment = 10;

  while (true) {
    await Future.delayed(const Duration(seconds: 1));

    final segmentIndex = (tick ~/ stepsPerSegment) % (waypoints.length - 1);
    final t = (tick % stepsPerSegment) / stepsPerSegment; // 0.0 → 1.0

    final from = waypoints[segmentIndex];
    final to = waypoints[(segmentIndex + 1) % waypoints.length];

    // Interpolación lineal entre los dos waypoints
    final lat = from.lat + (to.lat - from.lat) * t;
    final lon = from.lon + (to.lon - from.lon) * t;

    // Calcular heading (ángulo en grados desde el norte, sentido horario)
    final dLat = to.lat - from.lat;
    final dLon = to.lon - from.lon;
    final heading = (math.atan2(dLon, dLat) * 180 / math.pi + 360) % 360;

    // El tick 15 simula bus fantasma (>90s sin señal) para probar el ícono gris
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
