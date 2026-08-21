import 'package:flutter_riverpod/flutter_riverpod.dart';

class SelectedBusesNotifier extends StateNotifier<Set<String>> {
  SelectedBusesNotifier() : super({});

  /// Selección única: tocar un bus lo selecciona y deselecciona cualquier
  /// otro; tocar el mismo bus lo deselecciona.
  bool toggleBus(String busId) {
    state = state.contains(busId) ? {} : {busId};
    return true;
  }

  void clear() => state = {};
}

final selectedBusesProvider =
    StateNotifierProvider<SelectedBusesNotifier, Set<String>>((ref) {
  return SelectedBusesNotifier();
});
