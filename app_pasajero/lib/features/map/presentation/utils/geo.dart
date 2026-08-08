import 'dart:math';

const double _earthRadiusMeters = 6371000;

double haversineMeters(double lat1, double lon1, double lat2, double lon2) {
  final dLat = _toRad(lat2 - lat1);
  final dLon = _toRad(lon2 - lon1);
  final a = pow(sin(dLat / 2), 2) +
      cos(_toRad(lat1)) * cos(_toRad(lat2)) * pow(sin(dLon / 2), 2);
  return 2 * _earthRadiusMeters * asin(sqrt(a));
}

double _toRad(double deg) => deg * pi / 180;
