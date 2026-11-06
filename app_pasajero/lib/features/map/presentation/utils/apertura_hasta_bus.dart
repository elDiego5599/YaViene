import 'dart:async';

/// Lo que la pantalla deja ver en el momento de abrir el encuadre.
typedef MomentoDelMapa = ({
  bool selectorAbierto,
  bool busElegido,
  bool hayBuses,
});

/// Cuándo encuadrar el pin con el bus más cercano (AUD29-04).
///
/// Al elegir ruta pasan muchas cosas seguidas: el selector se cierra, el pin
/// salta a la ruta nueva, la hoja cambia de alto con la lista y llega el
/// primer lote. Si cada una movía la cámara, eran varios viajes de 800 ms
/// pisándose, y el mapa iba a un lado, al otro y se quedaba quieto (dueño,
/// 2026-11-06). Aquí todas solo piden, y la cámara se mueve una vez, cuando
/// la pantalla lleva [calma] sin cambiar.
///
/// Con el selector encima o un bus elegido no se gasta: espera al próximo
/// cambio. Sin buses encuadra el pin solo y vuelve con el primer lote. Ya
/// hecho, se rehace si la hoja cambia de alto, hasta que el dedo toca el
/// mapa: desde ahí la cámara es del usuario.
class AperturaHastaBus {
  AperturaHastaBus({required this.momento, required this.encuadrar});

  /// Lo que se espera desde el último cambio antes de mover la cámara. Pasa
  /// los 200 ms con que la hoja se asienta (`AppMotion.rapido`), que es lo
  /// último en moverse.
  static const calma = Duration(milliseconds: 250);

  final MomentoDelMapa Function() momento;
  final void Function() encuadrar;

  _Fase _fase = _Fase.quieta;
  Timer? _espera;

  /// Otra ruta: el encuadre vuelve a estar pendiente.
  void rutaElegida() {
    _fase = _Fase.pendiente;
    _programar();
  }

  /// Un lote de buses: solo cuenta si el encuadre aún no los incluyó.
  void lote() {
    if (_fase == _Fase.pendiente) _programar();
  }

  /// Cambió algo de lo que se ve: el selector, el pin o el alto de la hoja.
  void cambio() {
    if (_fase != _Fase.quieta) _programar();
  }

  /// El dedo en el mapa manda, haya abierto o no.
  void dedo() {
    _fase = _Fase.quieta;
    _espera?.cancel();
  }

  void dispose() => dedo();

  void _programar() {
    _espera?.cancel();
    _espera = Timer(calma, _encuadrarSiSePuede);
  }

  void _encuadrarSiSePuede() {
    final m = momento();
    if (m.selectorAbierto || m.busElegido) return;
    encuadrar();
    // Sin buses solo se vio el pin: el primer lote lo abre hasta el bus.
    if (m.hayBuses) _fase = _Fase.viva;
  }
}

enum _Fase { quieta, pendiente, viva }
