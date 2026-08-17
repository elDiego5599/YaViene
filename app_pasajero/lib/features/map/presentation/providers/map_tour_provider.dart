import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Controla el tour de primer uso del mapa (coach mark sobre la píldora de
/// búsqueda). Se muestra UNA vez en la vida del dispositivo: se persiste en
/// prefs para que ni el logout ni el cierre de la app lo vuelvan a disparar.
class MapTourController extends StateNotifier<bool> {
  MapTourController() : super(false);

  static const _kSeen = 'map_tour_seen';

  /// Muestra el tour si el usuario aún no lo ha visto. No hace nada si ya
  /// está visible (evita apilar overlay si llegan dos triggers en serie).
  Future<void> maybeShow() async {
    if (state) return;
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool(_kSeen) ?? false)) state = true;
  }

  /// Cierra el tour y lo marca como visto para siempre.
  Future<void> markSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kSeen, true);
    state = false;
  }
}

final mapTourProvider =
    StateNotifierProvider<MapTourController, bool>((ref) => MapTourController());