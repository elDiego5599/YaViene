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

    for (double y = 28; y < size.height * 0.58; y += 34) {
      for (double x = 18; x < size.width; x += 34) {
        final offset = ((y / 34).round().isEven) ? 0.0 : 12.0;
        canvas.drawCircle(Offset(x + offset, y), 1.6, dotPaint);
      }
    }

    final routeA = Path()
      ..moveTo(-20, size.height * 0.18)
      ..cubicTo(
        size.width * 0.25,
        size.height * 0.10,
        size.width * 0.38,
        size.height * 0.32,
        size.width * 0.62,
        size.height * 0.24,
      )
      ..cubicTo(
        size.width * 0.80,
        size.height * 0.18,
        size.width * 0.88,
        size.height * 0.36,
        size.width + 20,
        size.height * 0.30,
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
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
