// Conteo de buses cerca del usuario (2 km). Extraído de
// tracking_providers.dart para que el cálculo tenga su propio archivo.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utils/geo.dart';
import 'tracking_providers.dart';
import 'user_location_provider.dart';

const int nearbyRadiusMeters = 2000;

final nearbyBusesCountProvider =
    Provider.autoDispose.family<int?, String>((ref, routeId) {
  final positions =
      ref.watch(busPositionsSourceProvider(routeId)).value ?? const [];
  final location = ref.watch(userLocationProvider);
  if (!location.hasPosition) return null;
  var count = 0;
  for (final pos in positions) {
    if (pos.isGhostBus) continue;
    final distance =
        haversineMeters(location.lat!, location.lon!, pos.lat, pos.lon);
    if (distance <= nearbyRadiusMeters) count++;
  }
  return count;
});
