// Avisos activos: hasta 2 a la vez, con límite atómico.
// Antes vivía en tracking_providers.dart; ahora tiene su propio archivo.
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ActiveAlertsNotifier extends StateNotifier<Set<String>> {
  ActiveAlertsNotifier() : super({});

  /// Activa de forma idempotente. Devuelve false si se alcanzó el límite.
  /// Mantener el límite aquí evita que dos acciones asíncronas lo superen.
  bool activateAlert(String busId, {int maxActive = 2}) {
    if (state.contains(busId)) return true;
    if (state.length >= maxActive) return false;
    state = {...state, busId};
    return true;
  }

  void deactivateAlert(String busId) {
    if (!state.contains(busId)) return;
    state = {...state}..remove(busId);
  }

  void toggleAlert(String busId) {
    if (state.contains(busId)) {
      deactivateAlert(busId);
    } else {
      state = {...state, busId};
    }
  }

  void clear() => state = {};
}

final activeAlertsProvider =
    StateNotifierProvider<ActiveAlertsNotifier, Set<String>>((ref) {
  return ActiveAlertsNotifier();
});
