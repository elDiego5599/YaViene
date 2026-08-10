import 'package:flutter/material.dart';

/// Patrón de fondo tipo mapa (puntos y rutas) usado en login y onboarding.
class MapPatternPainter extends CustomPainter {
  const MapPatternPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final dotPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..style = PaintingStyle.fill;
    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.045)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    for (double y = 28; y < size.height; y += 34) {
      for (double x = 18; x < size.width; x += 34) {
        final offset = ((y / 34).round().isEven) ? 0.0 : 12.0;
        canvas.drawCircle(Offset(x + offset, y), 1.6, dotPaint);
      }
    }

    final routeA = Path()
      ..moveTo(-20, size.height * 0.16)
      ..cubicTo(
        size.width * 0.25,
        size.height * 0.08,
        size.width * 0.38,
        size.height * 0.30,
        size.width * 0.62,
        size.height * 0.22,
      )
      ..cubicTo(
        size.width * 0.80,
        size.height * 0.16,
        size.width * 0.88,
        size.height * 0.34,
        size.width + 20,
        size.height * 0.28,
      );
    canvas.drawPath(routeA, linePaint);

    final routeB = Path()
      ..moveTo(size.width * 0.12, -10)
      ..cubicTo(
        size.width * 0.06,
        size.height * 0.18,
        size.width * 0.28,
        size.height * 0.26,
        size.width * 0.22,
        size.height * 0.48,
      );
    canvas.drawPath(routeB, linePaint);

    final routeC = Path()
      ..moveTo(-20, size.height * 0.74)
      ..cubicTo(
        size.width * 0.18,
        size.height * 0.66,
        size.width * 0.40,
        size.height * 0.88,
        size.width * 0.62,
        size.height * 0.78,
      )
      ..cubicTo(
        size.width * 0.80,
        size.height * 0.70,
        size.width * 0.90,
        size.height * 0.86,
        size.width + 20,
        size.height * 0.80,
      );
    canvas.drawPath(routeC, linePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
