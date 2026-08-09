import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import '../utils/geo.dart';
import 'tracking_providers.dart';
import 'user_location_provider.dart';

/// Estado del ETA según lo que reporta el bus.
enum EtaState {
  /// Avanzando a velocidad normal.
  enRuta,

  /// Avanza muy lento (menos de 8 km/h): tráncón o embotellamiento.
  trancado,

  /// Prácticamente detenido (≤ 0.5 km/h).
  detenido,

  /// El usuario ya quedó atrás del bus en el recorrido (el bus pasó).
  yaPaso,
}

/// Sentido de marcha del bus. Lo reporta el propio bus (variable que cambia
/// en el punto de giro del recorrido): sin depender del rumbo, que se
/// confunde en rutas donde el bus sube un poco antes de devolverse.
enum EtaDirection {
  /// De ida: del origen hacia el destino del trazado.
  ida,

  /// De venida: regresando del destino hacia el origen.
  venida,

  /// El bus aún no reporta sentido (dispositivo antiguo): se asume ida.
  desconocido,
}

/// Velocidad mínima (km/h) usada para proyectar el ETA cuando el bus va en
/// tráncón: evita un "infinito" y refleja un avance lento pero real.
const double _stalledSpeedFloorKmh = 5;

/// Velocidad (km/h) por debajo de la cual se considera "tráncón".
const double stalledThresholdKmh = 8;

/// Estimación de llegada calculada sobre el recorrido real de la ruta.
class EtaEstimate {
  final EtaState state;
  final EtaDirection direction;

  /// Minutos estimados; null cuando el bus está detenido o ya pasó.
  final int? minutes;

  /// Distancia restante por el recorrido, en metros.
  final double remainingMeters;

  const EtaEstimate({
    required this.state,
    required this.direction,
    required this.minutes,
    required this.remainingMeters,
  });
}

EtaDirection _fromSentido(String? sentido) {
  switch (sentido) {
    case 'venida':
      return EtaDirection.venida;
    case 'ida':
      return EtaDirection.ida;
    default:
      return EtaDirection.desconocido;
  }
}

/// Cálculo puro (inyectable en tests).
///
/// Proyecta el bus y al usuario sobre la polilínea del recorrido; el ETA es
/// la distancia restante sobre la ruta dividida por la velocidad que reporta
/// el bus. El sentido (ida/venida) lo reporta el bus: un bus de venida que
/// viene hacia ti NO se marca como "ya pasó", y uno de ida que ya pasó sí.
/// Si el bus va en tráncón la velocidad baja y el ETA crece solo.
EtaEstimate? computeEta({
  required List<GeoPoint> points,
  required double busLat,
  required double busLon,
  required double userLat,
  required double userLon,
  required double speedKmh,
  required String? sentido,
}) {
  if (points.length < 2) return null;
  final direction = _fromSentido(sentido);
  final busProj =
      projectOntoPolyline(GeoPoint(lat: busLat, lon: busLon), points);
  final userProj =
      projectOntoPolyline(GeoPoint(lat: userLat, lon: userLon), points);

  // Venida: el bus recorre el trazado en reversa; le falta lo que va desde
  // su posición hacia atrás hasta llegar al usuario.
  final remaining = direction == EtaDirection.venida
      ? busProj.alongMeters - userProj.alongMeters
      : userProj.alongMeters - busProj.alongMeters;

  if (remaining <= 0) {
    return EtaEstimate(
      state: EtaState.yaPaso,
      direction: direction,
      minutes: null,
      remainingMeters: remaining,
    );
  }

  if (speedKmh <= 0.5) {
    return EtaEstimate(
      state: EtaState.detenido,
      direction: direction,
      minutes: null,
      remainingMeters: remaining,
    );
  }

  final state = speedKmh < stalledThresholdKmh ? EtaState.trancado : EtaState.enRuta;
  final effectiveSpeed =
      speedKmh < stalledThresholdKmh ? _stalledSpeedFloorKmh : speedKmh;
  final minutes = (remaining / 1000 / effectiveSpeed * 60).ceil();
  return EtaEstimate(
    state: state,
    direction: direction,
    minutes: minutes,
    remainingMeters: remaining,
  );
}

/// ETA en vivo del bus seleccionado. `null` si falta posición del bus, del
/// usuario o la geometría de la ruta aún no cargó.
final busEtaProvider = Provider.autoDispose.family<EtaEstimate?, String>(
    (ref, busId) {
  final route = ref.watch(selectedRouteProvider);
  if (route == null) return null;
  final location = ref.watch(userLocationProvider);
  if (!location.hasPosition) return null;

  final positions =
      ref.watch(busPositionsSourceProvider(route.id)).value ?? const <BusPosition>[];
  BusPosition? bus;
  for (final p in positions) {
    if (p.busId == busId) {
      bus = p;
      break;
    }
  }
  if (bus == null || bus.isGhostBus) return null;

  final trajectory = ref.watch(routeTrajectoryProvider(route.id)).value;
  if (trajectory == null || trajectory.points.length < 2) return null;

  return computeEta(
    points: trajectory.points,
    busLat: bus.lat,
    busLon: bus.lon,
    userLat: location.lat!,
    userLon: location.lon!,
    speedKmh: bus.speedKmh,
    sentido: bus.sentido,
  );
});
