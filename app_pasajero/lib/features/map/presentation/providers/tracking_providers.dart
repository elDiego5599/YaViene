import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import '../../domain/repositories/realtime_repository.dart';
import '../utils/geo.dart';
import 'realtime_providers.dart';
import 'user_location_provider.dart';

/// Arma un stream que mantiene el mapa `busId → BusPosition` escuchando los
/// eventos del socket (batch, live, left, hidden, removed) y filtrando por
/// las rutas indicadas.
Stream<List<BusPosition>> _buildRoutePositionsStream(
  RealtimeRepository service,
  Set<String> routeIds,
) {
  final controller = StreamController<List<BusPosition>>();
  final positions = <String, BusPosition>{};
  final processedEventIds = <String>{};
  Timer? emitTimer;

  void emitSnapshot() {
    if (!controller.isClosed) controller.add(positions.values.toList());
  }

  void scheduleLiveSnapshot() {
    if (emitTimer != null) return;
    emitTimer = Timer(const Duration(milliseconds: 200), () {
      emitTimer = null;
      emitSnapshot();
    });
  }

  bool belongsTo(dynamic routeId) => routeIds.contains(routeId);

  final batchSub = service.batchPositionStream.listen((batch) {
    final routeId = batch['routeId'] as String?;
    if (routeId == null || !belongsTo(routeId)) return;
    final buses = (batch['buses'] as List<dynamic>? ?? const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    positions.clear();
    for (final json in buses) {
      final pos = _jsonToBusPosition(json);
      positions[pos.busId] = pos;
    }
    if (positions.isNotEmpty) emitSnapshot();
  });

  final liveSub = service.busPositionStream.listen((json) {
    final pos = _jsonToBusPosition(json);
    if (!belongsTo(pos.routeId)) return;
    positions[pos.busId] = pos;
    scheduleLiveSnapshot();
  });

  final leftSub = service.busLeftStream.listen((event) {
    if (event['routeId'] != null && !belongsTo(event['routeId'])) return;
    final busId = event['busId'] as String?;
    if (busId != null && positions.remove(busId) != null) {
      emitSnapshot();
    }
  });

  final hiddenSub = service.busHiddenStream.listen((event) {
    if (event['routeId'] != null && !belongsTo(event['routeId'])) return;
    final eventId = event['eventId'] as String?;
    final busId = event['busId'] as String?;
    if (busId == null) return;
    if (eventId != null && !processedEventIds.add(eventId)) return;
    if (positions.remove(busId) != null) {
      emitSnapshot();
    }
  });

  final removedSub = service.busRemovedStream.listen((event) {
    if (event['routeId'] != null && !belongsTo(event['routeId'])) return;
    final busId = event['busId'] as String?;
    if (busId != null && positions.remove(busId) != null) {
      emitSnapshot();
    }
  });

  final visibleSub = service.busVisibleStream.listen((event) {
    if (event['routeId'] != null && !belongsTo(event['routeId'])) return;
    final eventId = event['eventId'] as String?;
    final busId = event['busId'] as String?;
    if (busId == null) return;
    if (eventId != null && !processedEventIds.add(eventId)) return;
    final position = event['position'];
    if (position is Map) {
      positions[busId] =
          _jsonToBusPosition(Map<String, dynamic>.from(position));
      emitSnapshot();
    }
  });

  controller.onCancel = () {
    batchSub.cancel();
    liveSub.cancel();
    leftSub.cancel();
    hiddenSub.cancel();
    removedSub.cancel();
    visibleSub.cancel();
    emitTimer?.cancel();
    controller.close();
  };

  return controller.stream;
}

final busPositionsSourceProvider = StreamProvider.autoDispose
    .family<List<BusPosition>, String>((ref, routeId) {
  final service = ref.watch(realtimeServiceProvider);
  service.subscribeToRoute(routeId);
  ref.onDispose(() => service.unsubscribeFromRoute(routeId));
  return _buildRoutePositionsStream(service, {routeId});
});

/// Radio de proximidad para el conteo "buses cerca de ti" (2 km).
const int nearbyRadiusMeters = 2000;

/// Cantidad de buses de la ruta a menos de [nearbyRadiusMeters] del centro
/// del usuario (GPS o pin). `null` si el usuario aún no tiene posición.
final nearbyBusesCountProvider =
    Provider.autoDispose.family<int?, String>((ref, routeId) {
  final positions =
      ref.watch(busPositionsSourceProvider(routeId)).value ?? const [];
  final location = ref.watch(userLocationProvider);
  if (!location.hasPosition) return null;
  var count = 0;
  for (final pos in positions) {
    if (pos.isGhostBus) continue;
    final distance = haversineMeters(
        location.lat!, location.lon!, pos.lat, pos.lon);
    if (distance <= nearbyRadiusMeters) count++;
  }
  return count;
});

BusPosition _jsonToBusPosition(Map<String, dynamic> json) {
  return BusPosition(
    busId: json['busId'] as String? ?? '???',
    routeId: json['routeId'] as String? ?? '',
    lat: (json['lat'] as num).toDouble(),
    lon: (json['lon'] as num).toDouble(),
    heading: (json['heading'] as num?)?.toDouble() ?? 0.0,
    speedKmh: (json['speedKmh'] as num?)?.toDouble() ?? 0.0,
    timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now(),
    isGhostBus: json['isGhost'] as bool? ?? false,
  );
}

class SelectedBusesNotifier extends StateNotifier<Set<String>> {  SelectedBusesNotifier() : super({});

  bool toggleBus(String busId) {
    if (state.contains(busId)) {
      state = {...state}..remove(busId);
      return true;
    } else {
      if (state.length >= 2) return false;
      state = {...state, busId};
      return true;
    }
  }

  void clear() => state = {};
}

final selectedBusesProvider =
    StateNotifierProvider<SelectedBusesNotifier, Set<String>>((ref) {
  return SelectedBusesNotifier();
});

class ActiveAlertsNotifier extends StateNotifier<Set<String>> {
  ActiveAlertsNotifier() : super({});

  void toggleAlert(String busId) {
    if (state.contains(busId)) {
      state = {...state}..remove(busId);
    } else {
      state = {...state, busId};
    }
  }
}

final activeAlertsProvider =
    StateNotifierProvider<ActiveAlertsNotifier, Set<String>>((ref) {
  return ActiveAlertsNotifier();
});
