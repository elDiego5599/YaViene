import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import 'realtime_providers.dart';

final busPositionsSourceProvider = StreamProvider.autoDispose
    .family<List<BusPosition>, String>((ref, routeId) {
       final service = ref.watch(realtimeServiceProvider);
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

      service.subscribeToRoute(routeId);

       final batchSub = service.batchPositionStream.listen((batch) {
         if (batch['routeId'] != routeId) return;
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
         if (pos.routeId != routeId) return;
         positions[pos.busId] = pos;
         scheduleLiveSnapshot();
      });

       final leftSub = service.busLeftStream.listen((event) {
          if (event['routeId'] != null && event['routeId'] != routeId) return;
          final busId = event['busId'] as String?;
          if (busId != null && positions.remove(busId) != null) {
            emitSnapshot();
          }
       });

       final hiddenSub = service.busHiddenStream.listen((event) {
          if (event['routeId'] != null && event['routeId'] != routeId) return;
          final eventId = event['eventId'] as String?;
          final busId = event['busId'] as String?;
          if (busId == null) return;
          if (eventId != null && !processedEventIds.add(eventId)) return;
          if (positions.remove(busId) != null) {
            emitSnapshot();
          }
       });

       final removedSub = service.busRemovedStream.listen((event) {
          if (event['routeId'] != null && event['routeId'] != routeId) return;
          final busId = event['busId'] as String?;
          if (busId != null && positions.remove(busId) != null) {
            emitSnapshot();
          }
       });

       final visibleSub = service.busVisibleStream.listen((event) {
          if (event['routeId'] != null && event['routeId'] != routeId) return;
          final eventId = event['eventId'] as String?;
          final busId = event['busId'] as String?;
          if (busId == null) return;
          if (eventId != null && !processedEventIds.add(eventId)) return;
          final position = event['position'];
          if (position is Map) {
            positions[busId] = _jsonToBusPosition(Map<String, dynamic>.from(position));
            emitSnapshot();
          }
       });

       ref.onDispose(() {
         service.unsubscribeFromRoute(routeId);
          batchSub.cancel();
          liveSub.cancel();
          leftSub.cancel();
          hiddenSub.cancel();
          removedSub.cancel();
          visibleSub.cancel();
          emitTimer?.cancel();
          controller.close();
       });

      return controller.stream;
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

class SelectedBusesNotifier extends StateNotifier<Set<String>> {
  SelectedBusesNotifier() : super({});

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
