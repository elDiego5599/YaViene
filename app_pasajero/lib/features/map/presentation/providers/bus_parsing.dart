// Validación defensiva de posiciones: un evento malformado no tumba la
// suscripción. Extraído de tracking_providers.dart.
import 'package:ya_viene_core/ya_viene_core.dart';

BusPosition? safeBusPosition(Map<String, dynamic> json) {
  try {
    return _jsonToBusPosition(json);
  } on FormatException {
    return null;
  } on TypeError {
    return null;
  }
}

/// El `timestamp` lo pone el servidor al recibir la posición, y el reloj del
/// teléfono no es el suyo: puede ir unos minutos corrido si alguien lo puso a
/// mano. Diez minutos de holgura cubren eso sin dejar pasar una fecha que no
/// tiene sentido.
const Duration _holguraDeReloj = Duration(minutes: 10);

/// Lo más vieja que puede llegar una posición que el servidor todavía da por
/// viva: a los 5 min sin publicar el bus pasa a «sin señal» (`GHOST_MS` en el
/// backend) y el barrido que lo marca corre cada 10 s. Una posición en vivo
/// más vieja que eso, holgura aparte, es un resto que no debería llegar.
const Duration _vidaEnVivo = Duration(minutes: 5, seconds: 10);

BusPosition _jsonToBusPosition(Map<String, dynamic> json) {
  final lat = (json['lat'] as num?)?.toDouble();
  final lon = (json['lon'] as num?)?.toDouble();
  if (lat == null || lon == null) {
    throw const FormatException('posición sin lat/lon');
  }
  final busId = (json['busId'] as String?)?.trim();
  final routeId = (json['routeId'] as String?)?.trim();
  if (busId == null || busId.isEmpty || routeId == null || routeId.isEmpty) {
    throw const FormatException('posición sin busId/routeId');
  }
  if (!lat.isFinite ||
      !lon.isFinite ||
      lat < -90 ||
      lat > 90 ||
      lon < -180 ||
      lon > 180) {
    throw const FormatException('posición fuera de rango');
  }
  // Antes una fecha que faltaba o no se entendía se volvía `DateTime.now()`,
  // y el bus salía como recién reportado aunque la posición tuviera horas.
  final timestamp = DateTime.tryParse(json['timestamp'] as String? ?? '');
  if (timestamp == null) {
    throw const FormatException('posición sin fecha válida');
  }
  final isGhost = json['isGhost'] as bool? ?? false;
  final ahora = DateTime.now();
  if (timestamp.difference(ahora) > _holguraDeReloj) {
    throw const FormatException('posición con fecha del futuro');
  }
  // Los buses sin señal no tienen tope: su fecha vieja es justo lo que se
  // enseña («Sin señal · hace 2 h»).
  if (!isGhost && ahora.difference(timestamp) > _vidaEnVivo + _holguraDeReloj) {
    throw const FormatException('posición en vivo demasiado vieja');
  }
  return BusPosition(
    busId: busId,
    routeId: routeId,
    lat: lat,
    lon: lon,
    // Sin rumbo queda null: rellenarlo con 0 giraba el bus hacia el norte.
    heading: (json['heading'] as num?)?.toDouble(),
    speedKmh: (json['speedKmh'] as num?)?.toDouble() ?? 0.0,
    sentido: json['sentido'] as String?,
    timestamp: timestamp,
    isGhostBus: isGhost,
  );
}
