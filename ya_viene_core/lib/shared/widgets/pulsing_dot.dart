import 'package:flutter/material.dart';

import '../../core/theme/app_motion.dart';

class PulsingDot extends StatefulWidget {
  final Color color;
  final double size;

  const PulsingDot({
    super.key,
    required this.color,
    this.size = 12,
  });

  @override
  State<PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  /// La curva se arma una vez, no en cada `build`.
  ///
  /// Antes se creaba ahí dentro, y cada `CurvedAnimation` se engancha como
  /// oyente del controlador y no se suelta sola. Como el punto vive dentro
  /// de un chip que se reconstruye cada vez que cambia el estado de la
  /// conexión, el controlador iba acumulando oyentes muertos toda la sesión,
  /// y cada uno de ellos volvía a evaluar la curva en cada cuadro.
  late CurvedAnimation _curva;
  late Animation<double> _opacidad;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppMotion.latido,
    )..repeat();
    _curva = CurvedAnimation(parent: _controller, curve: AppMotion.curvaCiclo);
    _opacidad = Tween<double>(begin: 0.2, end: 1.0).animate(_curva);
  }

  @override
  void dispose() {
    _curva.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacidad,
      // El punto lleva una sombra difuminada, y difuminar es de lo más caro
      // que se puede pedir por píxel. Sin frontera, `FadeTransition` tiene
      // que volver a rasterizar ese desenfoque en cada cuadro del ciclo de
      // dos segundos, para siempre, mientras el chip esté a la vista. Con
      // ella el punto se rasteriza una sola vez en su propia capa y lo único
      // que cambia por cuadro es el alfa de la capa.
      child: RepaintBoundary(
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: widget.color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: 0.5),
                blurRadius: 8,
                spreadRadius: 2,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
