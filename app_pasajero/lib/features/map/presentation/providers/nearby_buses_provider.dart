// Conteo de buses cerca del usuario (2 km) y el más cercano. Extraído de
// tracking_providers.dart para que el cálculo tenga su propio archivo.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

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

/// El bus de [routeId] más cercano al punto de espera, medido por la ruta
/// como en la hoja. Lo usa la guía para llevar el mapa a un bus que se
/// pueda tocar. `null` sin punto o sin buses con señal.
final busMasCercanoProvider =
    Provider.autoDispose.family<BusPosition?, String>((ref, routeId) {
  final positions =
      ref.watch(busPositionsSourceProvider(routeId)).value ?? const [];
  final location = ref.watch(userLocationProvider);
  if (!location.hasPosition) return null;
  final seguidor = ref.watch(seguidorRutaProvider(routeId));
  BusPosition? cercano;
  var menor = double.infinity;
  for (final pos in positions) {
    if (pos.isGhostBus) continue;
    final metros = distanciaAlBus(seguidor, pos, location.lat!, location.lon!);
    if (metros < menor) {
      menor = metros;
      cercano = pos;
    }
  }
  return cercano;
});
