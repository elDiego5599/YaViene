import 'dart:async';

/// Vuelve a elegir backend cuando la conexión en vivo lleva un rato caída.
///
/// `BackendResolver` elige una sola vez, al arrancar. Si el túnel de siempre
/// se caía con la app ya abierta, esa elección valía para toda la sesión: el
/// socket reintentaba contra el túnel muerto cada pocos segundos y la única
/// salida era cerrar la app y volver a abrirla. Esto vigila la conexión y,
/// tras [sinConexionMaxima] sin ella, vuelve a preguntar.
///
/// Con las esperas de `BackendResolver` (3 s y luego 10 s para la principal)
/// y el arranque en frío del respaldo (unos 8 s), la app queda en el respaldo
/// unos 51 s después de perder la principal.
///
/// Esto solo pregunta cuando se pierde la conexión. La vuelta a la principal
/// la vigila `BackendUrl`: en el respaldo, le pregunta cada 30 s
/// (`BackendUrl.vueltaCada`) y vuelve en cuanto contesta (dueño, 2026-10-26).
class BackendSupervisor {
  /// [reResolver] es la pregunta: elige otra vez y, si la respuesta cambia,
  /// cambia la URL (`BackendUrl.reResolver`).
  BackendSupervisor({
    required Future<void> Function() reResolver,
    this.paciencia = sinConexionMaxima,
  }) : _reResolver = reResolver;

  /// Cuánto se aguanta sin conexión antes de volver a preguntar. Son dos
  /// vueltas del reintento de 15 s del socket: con una sola, un corte breve
  /// del túnel ya mandaría la app al respaldo.
  static const Duration sinConexionMaxima = Duration(seconds: 30);

  final Future<void> Function() _reResolver;
  final Duration paciencia;

  Timer? _cuenta;
  bool _sinConexion = false;
  bool _preguntando = false;
  bool _cerrado = false;

  /// El socket perdió la conexión, o todavía no la logra. Empieza la cuenta
  /// si no corría ya: los avisos repetidos del mismo corte no la reinician.
  void conexionPerdida() {
    if (_cerrado) return;
    _sinConexion = true;
    if (!_preguntando) _cuenta ??= Timer(paciencia, _preguntar);
  }

  /// Hay conexión: la cuenta se olvida.
  void conexionRecuperada() => detener();

  /// La app cerró el socket a propósito (por ejemplo, al salir): que no haya
  /// conexión es lo esperado y no hay nada que vigilar.
  void detener() {
    _sinConexion = false;
    _cuenta?.cancel();
    _cuenta = null;
  }

  void dispose() {
    _cerrado = true;
    detener();
  }

  Future<void> _preguntar() async {
    _cuenta = null;
    _preguntando = true;
    try {
      await _reResolver();
    } catch (_) {
      // Una pregunta que falla vale lo mismo que una que no cambia nada: el
      // socket sigue reintentando y la cuenta vuelve a empezar.
    } finally {
      _preguntando = false;
    }
    // Si sigue sin conexión, se cuenta otra vez desde cero. Si la pregunta
    // cambió de backend, el socket nuevo avisa por su cuenta cuando conecta.
    if (!_cerrado && _sinConexion) _cuenta ??= Timer(paciencia, _preguntar);
  }
}
