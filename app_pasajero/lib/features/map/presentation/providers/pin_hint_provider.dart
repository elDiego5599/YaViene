import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Si el usuario ya descubrió que el pin de espera se arrastra.
///
/// Antes esto se contaba con un círculo blanco de cuatro flechas flotando
/// para siempre sobre la cabeza del pin: un símbolo sin palabras, que no se
/// retiraba nunca y competía con el pin por el mismo sitio. Un affordance se
/// enseña una vez y se aparta; lo que se enseña, además, se dice con
/// palabras. La pista vive ahora en la píldora de estado y desaparece en
/// cuanto el usuario arrastra el pin por primera vez.
class PinDragLearnedNotifier extends StateNotifier<bool> {
  PinDragLearnedNotifier() : super(true) {
    _load();
  }

  static const _key = 'pin_drag_learned';

  /// Arranca en `true` —"ya lo sabe"— a propósito: mientras se lee el disco
  /// no hay nada que mostrar, y para quien ya lo aprendió la pista no llega
  /// a asomarse. Para quien no, entra con la misma animación que el resto de
  /// la píldora.
  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    state = prefs.getBool(_key) ?? false;
  }

  Future<void> markLearned() async {
    if (state) return;
    state = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, true);
  }
}

final pinDragLearnedProvider =
    StateNotifierProvider<PinDragLearnedNotifier, bool>(
  (ref) => PinDragLearnedNotifier(),
);
