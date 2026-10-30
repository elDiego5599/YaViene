/// Lo que la pantalla deja ver en el momento de abrir el encuadre.
typedef MomentoDelMapa = ({
  bool selectorAbierto,
  bool busElegido,
  bool hayBuses,
});

/// Cuándo abrir la cámara del pin hasta el bus más cercano (AUD29-04).
///
/// La ruta se elige dentro del selector, y su primer lote suele llegar con
/// el selector aún encima: encuadrar ahí era gastarlo con un margen de abajo
/// que deja de valer al cerrarse, y el bus quedaba bajo la cabecera. Por eso
/// espera a que el selector se cierre y, ya hecho, se rehace cada vez que la
/// hoja cambia de alto, hasta que el dedo toca el mapa: desde ahí la cámara
/// es del usuario.
class AperturaHastaBus {
  _Fase _fase = _Fase.quieta;

  /// Otra ruta: el encuadre vuelve a estar pendiente de su primer lote.
  void rutaElegida() => _fase = _Fase.pendiente;

  /// El dedo en el mapa manda, haya abierto o no.
  void dedo() => _fase = _Fase.quieta;

  bool alLote(MomentoDelMapa m) => _abrirSiPendiente(m);

  bool alCerrarSelector(MomentoDelMapa m) => _abrirSiPendiente(m);

  /// La hoja cambió de alto: si ya se abrió, hay que rehacerlo.
  bool alMargen(MomentoDelMapa m) => _fase == _Fase.viva && _libre(m);

  bool _abrirSiPendiente(MomentoDelMapa m) {
    if (_fase != _Fase.pendiente || !_libre(m)) return false;
    _fase = _Fase.viva;
    return true;
  }

  static bool _libre(MomentoDelMapa m) =>
      m.hayBuses && !m.selectorAbierto && !m.busElegido;
}

enum _Fase { quieta, pendiente, viva }
