import 'package:flutter_riverpod/flutter_riverpod.dart';

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
