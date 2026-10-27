import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

/// El blanco de la carga, con el grano de la bienvenida y sin su color
/// (dueño, 2026-10-27: «solo la textura, no el color»; antes, una trama de
/// puntos fija).
class FondoTexturizado extends StatelessWidget {
  const FondoTexturizado({super.key});

  @override
  Widget build(BuildContext context) =>
      const ColoredBox(color: AppColors.surface, child: Grano());
}

/// El grano de la bienvenida (`PintorMatizado`), solo, sobre lo que haya
/// debajo: la carga y las cabeceras de Avisos, Buzón e Info (dueño,
/// 2026-10-27). Quieto: la semilla es fija, se pinta una vez y los goldens
/// no tiemblan.
class Grano extends StatelessWidget {
  const Grano({super.key});

  @override
  Widget build(BuildContext context) => const RepaintBoundary(
        child: CustomPaint(
          painter: PintorGrano(),
          size: Size.infinite,
          isComplex: true,
        ),
      );
}

class PintorGrano extends CustomPainter {
  const PintorGrano();

  /// Un grano cada 9 pt², la mitad blanco al 50 % y la mitad tinta al 3 %:
  /// los puntos oscuros solo restan un 3 % de luz, así que la letra pierde
  /// menos que con la trama de antes, que iba al 7 %.
  static void pintar(Canvas canvas, Size size, math.Random azar) {
    // Puntos de un píxel, claros y oscuros, casi invisibles uno por uno.
    final claros = <Offset>[];
    final oscuros = <Offset>[];
    final granos = (size.width * size.height / 9).round();
    for (var i = 0; i < granos; i++) {
      final p = Offset(
          azar.nextDouble() * size.width, azar.nextDouble() * size.height);
      (i.isEven ? claros : oscuros).add(p);
    }
    final punto = Paint()
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.square;
    canvas.drawPoints(ui.PointMode.points, claros,
        punto..color = Colors.white.withValues(alpha: 0.5));
    canvas.drawPoints(ui.PointMode.points, oscuros,
        punto..color = AppColors.ink.withValues(alpha: 0.03));
  }

  @override
  void paint(Canvas canvas, Size size) => pintar(canvas, size, math.Random(18));

  @override
  bool shouldRepaint(PintorGrano oldDelegate) => false;
}
