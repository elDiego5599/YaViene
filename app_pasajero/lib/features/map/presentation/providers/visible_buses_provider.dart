// Los buses que se dibujan: la fuente de la ruta, recortada al radio del
// punto de espera. La regla está en utils/bus_visibility.dart; aquí solo se
// junta con la ubicación, la selección y los avisos armados.
//
// Devuelve el mismo `AsyncValue<List<BusPosition>>` que
// `busPositionsSourceProvider` para que sea un cambio de una línea en quien
// lo consume. Y hay que consumirlo **solo en la vista**: quien mide (avisos,
// contadores) sigue leyendo la fuente sin filtrar.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

import '../utils/bus_visibility.dart';
// tracking_providers reexporta activeAlertsProvider y selectedBusesProvider.
import 'tracking_providers.dart';
import 'user_location_provider.dart';

export '../utils/bus_visibility.dart'
    show visibleRadiusMeters, visibleRadiusExitMeters;

class VisibleBusesNotifier
    extends AutoDisposeFamilyNotifier<AsyncValue<List<BusPosition>>, String> {
  /// Qué buses estaban dentro del radio en la vuelta anterior. Vive en la
  /// instancia y no en el estado a propósito: Riverpod conserva el notifier y
  /// vuelve a correr `build` con cada lote de posiciones, así que esto
  /// sobrevive entre lotes, que es justo lo que la histéresis necesita.
  final Set<String> _withinRadius = <String>{};

  @override
  AsyncValue<List<BusPosition>> build(String routeId) {
    final source = ref.watch(busPositionsSourceProvider(routeId));
    final location = ref.watch(userLocationProvider);
    final alwaysVisible = <String>{
      ...ref.watch(selectedBusesProvider),
      ...ref.watch(activeAlertsProvider),
    };

    final positions = source.valueOrNull;
    // Cargando o con error se devuelve tal cual, con su valor anterior si lo
    // trae: recortar un estado sin datos no aporta nada y perdería el
    // "refrescando" que la hoja usa para no parpadear.
    if (positions == null) return source;

    final result = filterBusesByRadius(
      positions: positions,
      userLat: location.lat,
      userLon: location.lon,
      alwaysVisible: alwaysVisible,
      previouslyWithinRadius: _withinRadius,
    );
    _withinRadius
      ..clear()
      ..addAll(result.withinRadius);
    return AsyncValue.data(result.buses);
  }
}

final visibleBusesProvider = NotifierProvider.autoDispose
    .family<VisibleBusesNotifier, AsyncValue<List<BusPosition>>, String>(
  VisibleBusesNotifier.new,
);

/// Cuántos buses de la ruta quedaron fuera del radio. Sirve para explicarle al
/// usuario un mapa vacío ("hay 4 buses, ninguno cerca de ti") en vez de
/// dejarlo pensando que la ruta no tiene servicio.
final busesOutOfRangeCountProvider =
    Provider.autoDispose.family<int, String>((ref, routeId) {
  final all = ref.watch(busPositionsSourceProvider(routeId)).valueOrNull;
  if (all == null) return 0;
  final visible = ref.watch(visibleBusesProvider(routeId)).valueOrNull;
  if (visible == null) return 0;
  final count = all.length - visible.length;
  return count > 0 ? count : 0;
});
