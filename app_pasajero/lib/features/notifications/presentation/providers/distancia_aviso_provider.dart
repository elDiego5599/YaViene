import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A qué distancia suena un aviso: la pone la persona, de 500 m a 3 km en
/// pasos de 100 m, con una rueda como la de la alarma del iPhone (dueño,
/// 2026-10-06). Por debajo de 500 m el bus ya está encima cuando suena; por
/// encima de 3 km el aviso deja de ser «ya viene». El servidor acepta el
/// mismo rango (`RADIO_MINIMO_M` / `RADIO_MAXIMO_M` del backend).
const int distanciaAvisoMinima = 500;
const int distanciaAvisoMaxima = 3000;
const int pasoDistanciaAviso = 100;

/// El kilómetro de siempre: donde arranca la rueda la primera vez y la
/// distancia de los avisos guardados por versiones de antes, que no la
/// traían (y la que el servidor pone a las apps que no la mandan).
const int distanciaAvisoInicial = 1000;

/// Las distancias que ofrece la rueda, de menor a mayor.
final List<int> distanciasDeAviso = List.unmodifiable([
  for (var m = distanciaAvisoMinima;
      m <= distanciaAvisoMaxima;
      m += pasoDistanciaAviso)
    m,
]);

/// [valor] si es una distancia de aviso que se puede usar; si no, `null`.
/// Lo que viene del disco no se cree.
int? distanciaAvisoValida(Object? valor) => valor is int &&
        valor >= distanciaAvisoMinima &&
        valor <= distanciaAvisoMaxima
    ? valor
    : null;

const _kDistanciaAviso = 'distancia_aviso_m';

/// La distancia que la persona guardó para sus avisos. `null` = no ha
/// guardado ninguna: al activar un aviso se le pregunta.
class DistanciaAvisoNotifier extends StateNotifier<int?> {
  DistanciaAvisoNotifier() : super(null);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    state = distanciaAvisoValida(prefs.get(_kDistanciaAviso));
  }

  Future<void> guardar(int metros) async {
    final valida = distanciaAvisoValida(metros);
    if (valida == null) {
      throw ArgumentError.value(metros, 'metros', 'fuera de 500–3000 m');
    }
    state = valida;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kDistanciaAviso, valida);
  }
}

final distanciaAvisoProvider =
    StateNotifierProvider<DistanciaAvisoNotifier, int?>(
        (ref) => DistanciaAvisoNotifier()..load());
