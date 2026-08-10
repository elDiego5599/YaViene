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

/// Banda de histéresis (m) alrededor del usuario: el bus solo se declara
/// "ya pasó" cuando quedó al menos a esta distancia detrás, proyectado en la
/// ruta. Evita que el estado parpadee cuando el bus cruza por tu punto.
const double _passHysteresisM = 150;

/// Una vez que el bus pasa por el usuario, su ETA se oculta durante la vuelta
/// de regreso hasta que esté a menos de esta distancia (m): "ya pasó · espera
/// la próxima vuelta" es más honesto que "viene en 85 min" con el bus a 40 km.
const double _returnSuppressionM = 5000;

/// Oculta el ETA cuando el bus ya pasó por el usuario y su vuelta de regreso
/// aún está lejos (a más de [thresholdM]): así el "ya pasó" es estable y el
/// bus que viene solo muestra tiempo cuando de verdad está llegando.
EtaEstimate? hideFarReturn(
  EtaEstimate? eta, {
  required bool hasPassed,
  required double thresholdM,
}) {
  if (eta == null || !hasPassed || eta.minutes == null) return eta;
  if (eta.remainingMeters <= thresholdM) return eta;
  return EtaEstimate(
    state: EtaState.yaPaso,
    direction: eta.direction,
    minutes: null,
    remainingMeters: eta.remainingMeters,
  );
}

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

  /// Posición del bus sobre la ruta rastreada con memoria (ver
  /// [EtaStabilizer.trackAlong]); si se omite se usa la proyección directa.
  double? trackedBusAlongM,
}) {
  if (points.length < 2) return null;
  final direction = _fromSentido(sentido);
  final busProj =
      projectOntoPolyline(GeoPoint(lat: busLat, lon: busLon), points);
  final userProj =
      projectOntoPolyline(GeoPoint(lat: userLat, lon: userLon), points);
  final busAlong = trackedBusAlongM ?? busProj.alongMeters;

  // Venida: el bus recorre el trazado en reversa; le falta lo que va desde
  // su posición hacia atrás hasta llegar al usuario.
  final remaining = direction == EtaDirection.venida
      ? busAlong - userProj.alongMeters
      : userProj.alongMeters - busAlong;

  // Histéresis: entre -150 m y 0 el bus acaba de cruzar tu punto; se sigue
  // mostrando "llegando" en vez de alternar con "ya pasó" a cada broadcast.
  if (remaining <= -_passHysteresisM) {
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
  final rawMinutes = (remaining / 1000 / effectiveSpeed * 60).ceil();
  // Mínimo "1 min": evita alternar 0/1 con el jitter del bus ya encima.
  final minutes = rawMinutes < 1 ? 1 : rawMinutes;
  return EtaEstimate(
    state: state,
    direction: direction,
    minutes: minutes,
    remainingMeters: remaining,
  );
}

/// Suaviza la velocidad reportada (EMA) y rastrea la posición del bus sobre la
/// ruta descartando saltos imposibles. El estado ("ya pasó" / distancia) se
/// mantiene estable aunque el bus publique jitter.
class EtaStabilizer {
  double? _emaSpeedKmh;

  /// Posición rastreada sobre la ruta, en metros (ver [trackAlong]).
  double? _trackedAlongM;

  /// Última vez que el bus pasó por el usuario (estado "ya pasó").
  DateTime? _lastPassedAt;

  /// El bus ya pasó por el usuario en algún momento de la sesión.
  bool get hasPassed => _lastPassedAt != null;

  /// Registra el paso del bus por el usuario.
  void recordPass() => _lastPassedAt = DateTime.now();

  /// Promedio móvil exponencial: 0.2 de la lectura nueva, 0.8 del histórico.
  double smoothSpeed(double raw) {
    if (raw < 0) raw = 0;
    _emaSpeedKmh = _emaSpeedKmh == null
        ? raw
        : _emaSpeedKmh! * 0.8 + raw * 0.2;
    return _emaSpeedKmh!;
  }

  /// Rastrea la posición del bus sobre la polilínea con memoria. La proyección
  /// "punto más cercano" salta entre la rama de ida y la de venida cuando el
  /// recorrido se dobla sobre sí mismo (R-106: brincos de ~30 km); el
  /// rastreador solo avanza lo que el bus alcanza a viajar en 20 s y descarta
  /// lo demás.
  double trackAlong({required double rawAlongMeters, required double speedKmh}) {
    if (_trackedAlongM == null || speedKmh <= 0) {
      _trackedAlongM = rawAlongMeters;
      return rawAlongMeters;
    }
    final maxDeltaM = speedKmh / 3.6 * 20;
    final delta = rawAlongMeters - _trackedAlongM!;
    final clamped = delta.abs() > maxDeltaM ? maxDeltaM * delta.sign : delta;
    _trackedAlongM = _trackedAlongM! + clamped;
    return _trackedAlongM!;
  }
}

/// Estabilizadores por bus y ruta (se limpian al dejar de observar).
final Map<String, EtaStabilizer> _stabilizers = {};

/// Estado del bus seleccionado para la hoja inferior: distancia restante por
/// la ruta (en [EtaEstimate.remainingMeters]), si ya pasó o está detenido.
/// `null` si falta posición del bus, del usuario o la geometría aún no cargó.
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

  final key = '${route.id}|$busId';
  final stabilizer = _stabilizers.putIfAbsent(key, EtaStabilizer.new);
  ref.onDispose(() => _stabilizers.remove(key));

  final smoothedSpeed = stabilizer.smoothSpeed(bus.speedKmh);
  final busProj = projectOntoPolyline(
      GeoPoint(lat: bus.lat, lon: bus.lon), trajectory.points);
  final trackedAlong = stabilizer.trackAlong(
      rawAlongMeters: busProj.alongMeters, speedKmh: smoothedSpeed);

  final eta = computeEta(
    points: trajectory.points,
    busLat: bus.lat,
    busLon: bus.lon,
    userLat: location.lat!,
    userLon: location.lon!,
    speedKmh: smoothedSpeed,
    sentido: bus.sentido,
    trackedBusAlongM: trackedAlong,
  );
  if (eta == null) return null;
  if (eta.state == EtaState.yaPaso) stabilizer.recordPass();
  // Una vez el bus pasó, su vuelta de regreso no muestra tiempo hasta que
  // esté cerca de verdad: "ya pasó · espera la próxima vuelta" es estable.
  return hideFarReturn(eta,
      hasPassed: stabilizer.hasPassed,
      thresholdM: _returnSuppressionM);
});
