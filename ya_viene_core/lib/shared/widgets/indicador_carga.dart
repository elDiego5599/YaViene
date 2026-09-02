import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_motion.dart';
import '../../core/theme/app_theme.dart';

/// La espera de Ya Viene: tres puntos que se encienden hacia la derecha.
///
/// La rueda de Material es de Material, no nuestra: llega con su azul de
/// fábrica, su grosor y su ritmo, y en pantallas donde todo lo demás está
/// medido —la marca, la tipografía, el verde— es lo único que se ve
/// prestado. Y aquí hay algo mejor que decir que "girando": la app entera
/// trata de algo que se acerca, así que la espera también avanza hacia ti.
///
/// Cabe en los 22 px de un botón y aguanta el tamaño de una pantalla vacía.
class IndicadorCarga extends StatefulWidget {
  const IndicadorCarga({
    super.key,
    this.color,
    this.size = 22,
    this.semanticsLabel,
  });

  /// Color de los puntos. Por defecto, el verde de la marca; dentro de un
  /// botón lleno se pasa el color del texto.
  final Color? color;

  /// Lado de la caja que ocupa. Los puntos se miden a partir de él.
  final double size;

  /// Una rueda girando no existe para VoiceOver. Si esta espera es lo único
  /// que está pasando en pantalla, hay que decirlo.
  final String? semanticsLabel;

  @override
  State<IndicadorCarga> createState() => _IndicadorCargaState();
}

class _IndicadorCargaState extends State<IndicadorCarga>
    with SingleTickerProviderStateMixin {
  static const int _puntos = 3;

  /// Cuánto se retrasa cada punto respecto al anterior, en fracción de
  /// ciclo. Es lo que convierte tres parpadeos en un movimiento.
  static const double _desfase = 0.16;

  /// Parte del ciclo que dura el pulso de un punto. El resto es descanso:
  /// sin él los tres estarían siempre encendidos y no se vería avanzar nada.
  static const double _pulso = 0.5;

  /// Se crea aquí y no en el primer `build` que lo necesite: con
  /// «reducir movimiento» puesto el bucle no se dibuja nunca, y un
  /// controlador perezoso se acababa creando dentro de `dispose()` —donde
  /// buscar el `TickerMode` del árbol ya no es legal.
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: AppMotion.pulso);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Quien pide menos movimiento no debería estar pagando un ticker por
    // cuadro para dibujar algo que no se mueve.
    if (AppMotion.reducido(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Intensidad del punto [i] en el instante [t] del ciclo, de 0 a 1.
  double _intensidad(double t, int i) {
    var fase = (t - i * _desfase) % 1.0;
    if (fase < 0) fase += 1;
    if (fase > _pulso) return 0;
    return math.sin(fase / _pulso * math.pi);
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? AppColors.primary;
    final lado = widget.size * 0.22;
    final hueco = widget.size * 0.13;

    Widget punto(double intensidad) {
      return Container(
        width: lado,
        height: lado,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.25 + 0.75 * intensidad),
          shape: BoxShape.circle,
        ),
      );
    }

    // Movimiento reducido: la fila se queda quieta y a media luz. Sigue
    // siendo la misma forma —nadie pierde de vista qué está mirando—, solo
    // que sin nada que se mueva.
    final Widget fila = AppMotion.reducido(context)
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < _puntos; i++) ...[
                if (i > 0) SizedBox(width: hueco),
                punto(0.45),
              ],
            ],
          )
        : AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final t = _controller.value;
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < _puntos; i++) ...[
                    if (i > 0) SizedBox(width: hueco),
                    // La escala acompaña a la luz: un punto que solo cambia
                    // de alfa parpadea, uno que además crece se acerca.
                    Transform.scale(
                      scale: 0.72 + 0.28 * _intensidad(t, i),
                      child: punto(_intensidad(t, i)),
                    ),
                  ],
                ],
              );
            },
          );

    return Semantics(
      label: widget.semanticsLabel,
      // Tres puntos no tienen nada que anunciar por su cuenta.
      excludeSemantics: true,
      child: RepaintBoundary(
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: Center(child: fila),
        ),
      ),
    );
  }
}
