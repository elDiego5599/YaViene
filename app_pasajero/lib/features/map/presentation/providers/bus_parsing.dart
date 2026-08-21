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
  return BusPosition(
    busId: busId,
    routeId: routeId,
    lat: lat,
    lon: lon,
    heading: (json['heading'] as num?)?.toDouble() ?? 0.0,
    speedKmh: (json['speedKmh'] as num?)?.toDouble() ?? 0.0,
    sentido: json['sentido'] as String?,
    timestamp:
        DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now(),
    isGhostBus: json['isGhost'] as bool? ?? false,
  );
}
