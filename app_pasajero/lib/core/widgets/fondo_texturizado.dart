import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

/// El blanco de la carga, la bienvenida, Avisos, Buzón e Info, con una trama
/// de puntos fija en la tinta de la marca (dueño, 2026-10-19: «fondo blanco
/// pero texturizado»). Quieta y sin azar: se pinta una vez y los goldens no
/// tiemblan.
class FondoTexturizado extends StatelessWidget {
  const FondoTexturizado({super.key});

  @override
  Widget build(BuildContext context) => const RepaintBoundary(
        child: CustomPaint(
          painter: PintorFondoTexturizado(),
          size: Size.infinite,
          isComplex: true,
        ),
      );
}

class PintorFondoTexturizado extends CustomPainter {
  const PintorFondoTexturizado();

  /// 16 pt entre puntos: la retícula de 8 de la app, al doble.
  static const double separacion = 16;

  /// 0,8 pt de radio: un punto de 1,6 pt, que se ve como grano y no como
  /// lunares.
  static const double radio = 0.8;

  /// La tinta al 7 %: a 3,5 % no se veía en el teléfono. Lo más oscuro queda
  /// en #EEEFF0, y sobre eso `textSecondary`, el gris más claro con texto,
  /// sigue a 4,68:1 (WCAG pide 4,5:1); `textBody` a 6,58:1 y la tinta a
  /// 15,7:1.
  static const double opacidad = 0.07;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawColor(AppColors.surface, BlendMode.src);
    final puntos = <Offset>[
      for (var y = separacion / 2; y < size.height; y += separacion)
        for (var x = separacion / 2; x < size.width; x += separacion)
          Offset(x, y),
    ];
    // Una sola llamada para toda la trama, no un círculo por punto.
    canvas.drawPoints(
        ui.PointMode.points,
        puntos,
        Paint()
          ..color = AppColors.ink.withValues(alpha: opacidad)
          ..strokeWidth = radio * 2
          ..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(PintorFondoTexturizado oldDelegate) => false;
}
