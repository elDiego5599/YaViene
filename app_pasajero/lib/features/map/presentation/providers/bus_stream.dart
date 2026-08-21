// Stream de posiciones por ruta: escucha batch/live/left/hidden/removed del
// socket y emite snapshots filtrados. Extraído de tracking_providers.dart
// para que el stream tenga su propio archivo.
import 'dart:async';

import 'package:ya_viene_core/ya_viene_core.dart';

import '../../domain/repositories/realtime_repository.dart';

import 'bus_parsing.dart';

Stream<List<BusPosition>> buildRoutePositionsStream(
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
    final buses = batch['buses'];
    positions.clear();
    if (buses is List) {
      for (final item in buses) {
        if (item is! Map) continue;
        final Map<String, dynamic> json;
        try {
          json = Map<String, dynamic>.from(item);
        } catch (_) {
          continue;
        }
        final pos = safeBusPosition(json);
        if (pos != null) positions[pos.busId] = pos;
      }
    }
    emitSnapshot();
  });

  final liveSub = service.busPositionStream.listen((json) {
    final pos = safeBusPosition(json);
    if (pos == null) return;
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
    if (eventId != null) {
      if (!processedEventIds.add(eventId)) return;
      if (processedEventIds.length > 5000) processedEventIds.clear();
    }
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
    if (eventId != null) {
      if (!processedEventIds.add(eventId)) return;
      if (processedEventIds.length > 5000) processedEventIds.clear();
    }
    final position = event['position'];
    if (position is Map) {
      final Map<String, dynamic> json;
      try {
        json = Map<String, dynamic>.from(position);
      } catch (_) {
        return;
      }
      final pos = safeBusPosition(json);
      if (pos != null) {
        positions[busId] = pos;
        emitSnapshot();
      }
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
