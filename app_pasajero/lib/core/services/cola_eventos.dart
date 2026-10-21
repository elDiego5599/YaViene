import 'dart:async';

/// Stream broadcast que conserva el último evento hasta que haya lector.
/// Útil para callbacks nativos que pueden adelantarse al montaje de la vista.
class ColaEventos<T> {
  ColaEventos() {
    _eventos = StreamController<T>.broadcast(onListen: _entregarPendiente);
  }

  late final StreamController<T> _eventos;
  T? _pendiente;
  bool _hayPendiente = false;

  Stream<T> get stream => _eventos.stream;

  void agregar(T evento) {
    if (!_eventos.hasListener) {
      _pendiente = evento;
      _hayPendiente = true;
      return;
    }
    _eventos.add(evento);
  }

  void _entregarPendiente() {
    if (!_hayPendiente) return;
    final evento = _pendiente as T;
    _pendiente = null;
    _hayPendiente = false;
    scheduleMicrotask(() {
      if (_eventos.hasListener) _eventos.add(evento);
    });
  }
}
