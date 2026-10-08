import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

import 'bus_stream.dart';
import 'realtime_providers.dart';

export 'active_alerts_provider.dart';
export 'bus_stream.dart';
export 'nearby_buses_provider.dart';
export 'selected_buses_provider.dart';

final busPositionsSourceProvider = StreamProvider.autoDispose
    .family<List<BusPosition>, String>((ref, routeId) {
  final service = ref.watch(realtimeServiceProvider);
  service.subscribeToRoute(routeId);
  ref.onDispose(() => service.unsubscribeFromRoute(routeId));
  return buildRoutePositionsStream(service, {routeId});
});

/// Quien sigue a los buses de una ruta por su recorrido, para medir la
/// distancia por la calle y no en línea recta. Recuerda dónde iba cada bus
/// (no salta de carril en una calle de ida y vuelta), así que la hoja y el
/// vigía de avisos comparten el mismo mientras alguno lo escuche. `null`
/// sin recorrido: se mide en línea recta (`distanciaAlBus`).
final seguidorRutaProvider =
    Provider.autoDispose.family<SeguidorRuta?, String>((ref, routeId) {
  final puntos =
      ref.watch(routeTrajectoryProvider(routeId)).valueOrNull?.points;
  final ruta = puntos == null ? null : RutaMedible.de(puntos);
  return ruta == null ? null : SeguidorRuta(ruta);
});
