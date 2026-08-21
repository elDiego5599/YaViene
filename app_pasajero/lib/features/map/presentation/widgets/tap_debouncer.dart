// Evita el doble toggle cuando el mismo toque dispara dos eventos
// (feature#onTap y map#onMapClick) casi en paralelo. Guarda el future en
// vuelo y lo reutiliza 400 ms.
import 'dart:async';
import 'dart:math' as math;

class TapDebouncer {
  Future<bool>? _pending;
  DateTime? _pendingAt;

  Future<bool> run(
    math.Point<double> point,
    Future<bool> Function(math.Point<double> point) action,
  ) {
    final pending = _pending;
    if (pending != null &&
        DateTime.now().difference(_pendingAt!) <
            const Duration(milliseconds: 400)) {
      return pending;
    }
    _pendingAt = DateTime.now();
    final future = action(point);
    _pending = future;
    return future;
  }
}
