import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

/// Un movimiento que late y descansa: corre [dura], se queda quieto
/// [pausa] y vuelve a empezar.
///
/// Lo usan el destello de «Ruta activa» y el toque del bus de «Toca un bus
/// en el mapa». Los dos están encima del mapa nativo: un bucle continuo lo
/// haría recomponer cada cuadro para siempre, así que la pausa es un
/// `Timer` y no pinta nada. Por lo mismo, `pumpAndSettle` se asienta.
///
/// [builder] recibe `t` de 0 a 1 a lo largo del latido; en la pausa se
/// queda en 1. Con el movimiento reducido del sistema no late: `t` es 0 y
/// `quieto` es `true`, para que quien dibuja elija su pose de reposo.
class Latido extends StatefulWidget {
  const Latido({
    super.key,
    required this.dura,
    required this.pausa,
    required this.builder,
    this.child,
  });

  final Duration dura;
  final Duration pausa;
  final Widget Function(
    BuildContext context,
    double t,
    bool quieto,
    Widget? child,
  ) builder;
  final Widget? child;

  @override
  State<Latido> createState() => _LatidoState();
}

class _LatidoState extends State<Latido> with SingleTickerProviderStateMixin {
  late final AnimationController _t = AnimationController(
    vsync: this,
    duration: widget.dura,
  )..addStatusListener((estado) {
      if (estado == AnimationStatus.completed) _descansar();
    });
  Timer? _siguiente;
  bool _quieto = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final quieto = AppMotion.reducido(context);
    if (quieto == _quieto && (_t.isAnimating || _siguiente != null)) return;
    _quieto = quieto;
    _siguiente?.cancel();
    _siguiente = null;
    if (quieto) {
      _t.value = 0;
    } else {
      _t.forward(from: 0);
    }
  }

  void _descansar() {
    _siguiente = Timer(widget.pausa, () {
      _siguiente = null;
      if (mounted && !_quieto) _t.forward(from: 0);
    });
  }

  @override
  void dispose() {
    _siguiente?.cancel();
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _t,
        child: widget.child,
        builder: (context, child) =>
            widget.builder(context, _t.value, _quieto, child),
      );
}
