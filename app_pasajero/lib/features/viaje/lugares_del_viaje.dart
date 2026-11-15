// El buscador de lugares (D25) y sus recientes, tal como los usa el
// planificador.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

/// Los recientes del buscador en las preferencias del teléfono. No salen
/// de él (Ley 1581) y se pueden volver a buscar en dos toques, así que
/// caben en SharedPreferences (`PrefsKeys`).
class AlmacenEnPreferencias implements AlmacenDeRecientes {
  static const llave = 'lugares_recientes';

  @override
  Future<String?> leer() async =>
      (await SharedPreferences.getInstance()).getString(llave);

  @override
  Future<void> escribir(String? texto) async {
    final prefs = await SharedPreferences.getInstance();
    texto == null
        ? await prefs.remove(llave)
        : await prefs.setString(llave, texto);
  }
}

final recientesDeLugaresProvider = Provider<RecientesDeLugares>(
  (ref) => RecientesDeLugares(AlmacenEnPreferencias()),
);

/// El índice viene dentro de la app; se lee una vez y se queda.
final buscadorDeLugaresProvider =
    FutureProvider<BuscadorDeLugares>((ref) => BuscadorLocal.cargar());
