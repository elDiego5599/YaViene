import 'package:flutter/material.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

/// Pulso "radar" bajo el pin del usuario: un círculo verde que crece y se
/// desvanece en bucle, con un punto sólido en el centro que marca el punto
/// exacto de espera. Todo el dibujo es Flutter puro encima del mapa nativo.
class HaloPainter extends CustomPainter {
  const HaloPainter({required this.center, required this.phase});

  final Offset center;

  /// 0..1 dentro del ciclo de 1.8 s del AnimationController.
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    final t = phase.clamp(0.0, 1.0);
    final radius = 14.0 + 30.0 * t;
    final opacity = (1.0 - t) * 0.32;
    canvas.drawCircle(
      center,
      radius,
      Paint()..color = AppColors.primary.withValues(alpha: opacity),
    );
    canvas.drawCircle(
      center,
      5,
      Paint()..color = AppColors.primary.withValues(alpha: 0.9),
    );
  }

  @override
  bool shouldRepaint(HaloPainter oldDelegate) =>
      oldDelegate.center != center || oldDelegate.phase != phase;
}
