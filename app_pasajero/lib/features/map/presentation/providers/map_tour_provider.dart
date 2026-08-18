import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Paso del tour de primer uso que está visible ahora (null = ninguno).
enum MapTourKind {
  /// Coach mark sobre la píldora de búsqueda (se dispara con ubicación lista).
  pill,

  /// Coach mark sobre el botón de aviso del bus seleccionado (primer bus
  /// tocado): explica la alarma y el comportamiento en segundo plano.
  bus,
}

/// Controla el tour de primer uso del mapa. Cada paso se muestra UNA vez en
/// la vida del dispositivo: se persisten en prefs para que ni el logout ni el
/// cierre de la app los vuelvan a disparar.
class MapTourController extends StateNotifier<MapTourKind?> {
  MapTourController() : super(null);

  static const _kPillSeen = 'map_tour_seen';
  static const _kBusSeen = 'map_tour_bus_seen';

  bool _isSeen(MapTourKind kind) =>
      kind == MapTourKind.pill ? _pillSeen : _busSeen;
  bool _pillSeen = false;
  bool _busSeen = false;

  /// Marca el paso como visible si el usuario aún no lo ha visto. No hace
  /// nada si ya hay otro paso mostrándose (evita apilar overlays).
  Future<void> maybeShow(MapTourKind kind) async {
    if (state != null) return;
    final prefs = await SharedPreferences.getInstance();
    _pillSeen = prefs.getBool(_kPillSeen) ?? false;
    _busSeen = prefs.getBool(_kBusSeen) ?? false;
    if (!_isSeen(kind)) state = kind;
  }

  /// Cierra el paso actual (o el indicado) y lo marca como visto para
  /// siempre. Sin argumento marca el que esté visible.
  Future<void> markSeen([MapTourKind? kind]) async {
    final target = kind ?? state;
    final prefs = await SharedPreferences.getInstance();
    if (target == MapTourKind.pill) {
      await prefs.setBool(_kPillSeen, true);
    } else if (target == MapTourKind.bus) {
      await prefs.setBool(_kBusSeen, true);
    }
    state = null;
  }
}

final mapTourProvider =
    StateNotifierProvider<MapTourController, MapTourKind?>(
        (ref) => MapTourController());