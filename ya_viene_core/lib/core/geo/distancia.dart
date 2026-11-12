import 'dart:math';

const double _radioTierraMetros = 6371000;

/// Metros en línea recta, sobre la esfera, entre dos puntos.
///
/// Vive en el core porque lo usan el pasajero (bus, pin, guía) y los
/// puntos de recarga (`puntosCerca`).
double haversineMeters(double lat1, double lon1, double lat2, double lon2) {
  final dLat = _aRadianes(lat2 - lat1);
  final dLon = _aRadianes(lon2 - lon1);
  final a = pow(sin(dLat / 2), 2) +
      cos(_aRadianes(lat1)) * cos(_aRadianes(lat2)) * pow(sin(dLon / 2), 2);
  // El redondeo de coma flotante puede llevar `a` apenas fuera de [0, 1]
  // para puntos coincidentes o antipodales; asin() no acepta ese valor.
  final safeA = a.toDouble().clamp(0.0, 1.0);
  return 2 * _radioTierraMetros * asin(sqrt(safeA));
}

double _aRadianes(double grados) => grados * pi / 180;
