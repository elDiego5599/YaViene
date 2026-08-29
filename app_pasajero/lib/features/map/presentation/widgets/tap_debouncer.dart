// Evita el doble toggle cuando el mismo toque dispara dos eventos
// (feature#onTap y map#onMapClick) casi en paralelo. Guarda el future en
// vuelo y lo reutiliza mientras el segundo evento sea *el mismo toque*.
import 'dart:async';
import 'dart:math' as math;

/// Los dos eventos de un mismo toque llegan con la misma coordenada de
/// pantalla salvo redondeo; dos toques distintos —dos buses— caen mucho más
/// lejos que esto. Sin comparar el punto, tocar un bus y otro en menos de
/// 400 ms devolvía el resultado del primero y el segundo toque se perdía.
const double _sameTapRadius = 24;

class TapDebouncer {
  Future<bool>? _pending;
  DateTime? _pendingAt;
  math.Point<double>? _pendingPoint;

  Future<bool> run(
    math.Point<double> point,
    Future<bool> Function(math.Point<double> point) action,
  ) {
    final pending = _pending;
    if (pending != null &&
        DateTime.now().difference(_pendingAt!) <
            const Duration(milliseconds: 400) &&
        _isSameTap(_pendingPoint!, point)) {
      return pending;
    }
    _pendingAt = DateTime.now();
    _pendingPoint = point;
    final future = action(point);
    _pending = future;
    // Sin esto el future se quedaba guardado para siempre y solo lo tapaba el
    // reloj: dentro de la ventana, cualquier toque devolvía aquel resultado
    // aunque la selección ya hubiera terminado.
    // Se limpia por las dos ramas, y la de error se traga aquí: quien llamó a
    // run() ya recibe el future original con su excepción; si además la
    // dejáramos escapar por esta copia, saldría como error sin capturar.
    unawaited(future.then<void>(
      (_) => _clear(future),
      onError: (Object _, StackTrace __) => _clear(future),
    ));
    return future;
  }

  void _clear(Future<bool> future) {
    if (identical(_pending, future)) {
      _pending = null;
      _pendingPoint = null;
    }
  }

  bool _isSameTap(math.Point<double> a, math.Point<double> b) {
    final dx = a.x - b.x;
    final dy = a.y - b.y;
    return dx * dx + dy * dy <= _sameTapRadius * _sameTapRadius;
  }
}
