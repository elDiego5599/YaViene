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
