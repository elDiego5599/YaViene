import 'package:flutter/widgets.dart';

import '../../core/theme/app_motion.dart';

/// La espera de una lista: su forma, latiendo, en vez de un hueco.
///
/// [IndicadorCarga] dice «algo viene»; aquí se sabe además qué viene —filas
/// de buses, de empresas, de rutas—, y dibujar su forma deja el sitio
/// tomado: cuando llegan los datos no salta nada, solo se llenan. Cada app
/// dibuja sus filas fantasma ([child]); este widget pone el latido, el
/// rótulo para el lector de pantalla y el respeto a «reducir movimiento».
class CargaFantasma extends StatefulWidget {
  const CargaFantasma({
    super.key,
    required this.semanticsLabel,
    required this.child,
  });

  /// Lo que un lector de pantalla dice en lugar de las filas, que son forma
  /// y no contenido.
  final String semanticsLabel;

  /// Las filas fantasma, con la forma de las de verdad.
  final Widget child;

  @override
  State<CargaFantasma> createState() => _CargaFantasmaState();
}

class _CargaFantasmaState extends State<CargaFantasma>
    with SingleTickerProviderStateMixin {
  /// Ni tan tenue que parezca vacío ni tan fuerte que parezca contenido.
  static const double _min = 0.45;
  static const double _max = 0.9;

  /// Con movimiento reducido, quieta a media luz: la misma forma, sin bucle.
  static const double _quieta = 0.65;

  /// Se crea aquí y no al primer `build`, por la misma razón que en
  /// [IndicadorCarga]: con movimiento reducido no se usa nunca y crearlo
  /// tarde caía dentro de `dispose()`.
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.pulso,
  );
  late final Animation<double> _latido = CurvedAnimation(
    parent: _controller,
    curve: AppMotion.curvaCiclo,
  ).drive(Tween(begin: _max, end: _min));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reducido(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filas = RepaintBoundary(child: widget.child);
    // `container`: un nodo propio, para que el rótulo no se funda con el de
    // la tarjeta o la hoja que lo envuelve.
    return Semantics(
      container: true,
      label: widget.semanticsLabel,
      excludeSemantics: true,
      child: AppMotion.reducido(context)
          ? Opacity(opacity: _quieta, child: filas)
          : AnimatedBuilder(
              animation: _latido,
              child: filas,
              builder: (_, child) =>
                  Opacity(opacity: _latido.value, child: child),
            ),
    );
  }
}
