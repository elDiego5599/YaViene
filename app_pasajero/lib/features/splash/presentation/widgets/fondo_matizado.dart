import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

/// El fondo del arranque (dueño, 2026-10-18: «texturizado matizado, que
/// tenga como azulito con verde suavecito»): manchas grandes y difusas de
/// azul y verde muy claros sobre un blanco frío, con grano fino encima para
/// que se lea como papel y no como degradado de pantalla. Quieto: lo que se
/// mueve es la escena de encima.
///
/// Entra en un fundido corto sobre el blanco del arranque nativo, para que
/// el relevo no salte. Con «Reducir movimiento» sale entero de una vez.
/// La tinta se lee AAA en todo el fondo (`test/fondo_matizado_test.dart`).
class FondoMatizado extends StatelessWidget {
  const FondoMatizado({super.key});

  /// Lo que tarda en aparecer: menos que la torre en armarse.
  static const Duration fundido = Duration(milliseconds: 300);

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: AppMotion.duracion(context, fundido),
      curve: Curves.easeOut,
      builder: (context, t, child) => Opacity(opacity: t, child: child),
      // Aparte: el fondo se pinta una vez y la escena anima encima.
      child: const RepaintBoundary(
        child: CustomPaint(painter: PintorMatizado(), size: Size.infinite),
      ),
    );
  }
}

/// El matizado, quieto. Siempre la misma foto: la semilla es fija.
class PintorMatizado extends CustomPainter {
  const PintorMatizado();

  /// Un blanco apenas frío, para que el matiz no se vea a parches.
  static const _base = Color(0xFFF3F8FA);

  /// (color, centro en fracción de la pantalla, radio en fracción del ancho):
  /// el azul arriba a la izquierda y abajo, el verde cruzado a la derecha.
  static const _manchas = [
    (Color(0xFFD3E4F6), Offset(0.05, 0.08), 1.0),
    (Color(0xFFD2EFDF), Offset(1.0, 0.32), 0.95),
    (Color(0xFFD8E6F8), Offset(0.1, 0.72), 0.85),
    (Color(0xFFD6F1E3), Offset(0.85, 0.98), 0.9),
  ];

  static const _azul = Color(0xFFC9DCF3);
  static const _verde = Color(0xFFC8EBD7);

  @override
  void paint(Canvas canvas, Size size) {
    final todo = Offset.zero & size;
    canvas.drawRect(todo, Paint()..color = _base);
    for (final (color, centro, radio) in _manchas) {
      final c = Offset(centro.dx * size.width, centro.dy * size.height);
      canvas.drawRect(
        todo,
        Paint()
          ..shader = RadialGradient(
            colors: [color, color.withValues(alpha: 0)],
          ).createShader(
              Rect.fromCircle(center: c, radius: radio * size.width)),
      );
    }
    final azar = math.Random(18);
    // El matiz: nubes chicas y borrosas de los dos tonos.
    final nube = Paint()
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, size.width * 0.06);
    for (var i = 0; i < 26; i++) {
      final c = Offset(
          azar.nextDouble() * size.width, azar.nextDouble() * size.height);
      final r = size.width * (0.06 + azar.nextDouble() * 0.12);
      canvas.drawCircle(
        c,
        r,
        nube
          ..color = (i.isEven ? _azul : _verde)
              .withValues(alpha: 0.35 + azar.nextDouble() * 0.3),
      );
    }
    // El grano: puntos de un píxel, claros y oscuros, casi invisibles uno
    // por uno.
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
        punto..color = AppColors.ink.withValues(alpha: 0.05));
  }

  @override
  bool shouldRepaint(PintorMatizado antes) => false;
}
