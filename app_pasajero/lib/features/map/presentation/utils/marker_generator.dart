import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class MarkerGenerator {
  /// Dibuja el marcador premium basado en el diseño del usuario (hola.svg)
  /// directamente en memoria usando Canvas. Súper rápido, 0 dependencias.
  static Future<Uint8List> generateBusMarker({bool isGhost = false}) async {
    const double size = 160.0; // Alta resolución para retina
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Escalar dibujo original (512x512) al tamaño deseado
    canvas.scale(size / 512.0);

    // Colores basados en el tema
    final Color primaryDeep = isGhost ? const Color(0xFF94A3B8) : const Color(0xFF14274E);
    final Color emerald = isGhost ? const Color(0xFFCBD5E1) : const Color(0xFF00A859);
    final Color yellow = isGhost ? const Color(0xFFE2E8F0) : const Color(0xFFFFC107);
    const Color white = Color(0xFFFFFFFF);

    final Paint paint = Paint()..style = PaintingStyle.fill;

    // 1. Fondo: Azul Marino redondeado
    paint.color = primaryDeep;
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(0, 0, 512, 512), const Radius.circular(115)),
      paint,
    );

    // 2. Pin de ubicación (Emerald)
    paint.color = emerald;
    final Path pinPath = Path()
      ..moveTo(256, 70)
      ..cubicTo(167, 70, 95, 142, 95, 231)
      ..cubicTo(95, 335, 235, 465, 245, 475)
      ..cubicTo(251, 481, 261, 481, 267, 475)
      ..cubicTo(277, 465, 417, 335, 417, 231)
      ..cubicTo(417, 142, 345, 70, 256, 70)
      ..close();
    canvas.drawPath(pinPath, paint);

    // 3. Núcleo amarillo
    paint.color = yellow;
    canvas.drawCircle(const Offset(256, 225), 85, paint);

    // 4. Llantas traseras
    paint.color = white;
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(216, 255, 16, 24), const Radius.circular(6)), paint);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(280, 255, 16, 24), const Radius.circular(6)), paint);

    // 5. Cuerpo del bus (Blanco)
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(210, 180, 92, 85), const Radius.circular(16)), paint);

    // 6. Parabrisas (Azul Marino)
    paint.color = primaryDeep;
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(222, 195, 68, 32), const Radius.circular(6)), paint);

    // 7. Faros amarillos
    paint.color = yellow;
    canvas.drawCircle(const Offset(228, 245), 8, paint);
    canvas.drawCircle(const Offset(284, 245), 8, paint);

    // 8. Parrilla
    paint.color = primaryDeep;
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(246, 243, 20, 4), const Radius.circular(2)), paint);

    // Ondas de conectividad superiores (solo si está activo)
    if (!isGhost) {
      final Paint strokePaint = Paint()
        ..color = white.withValues(alpha: 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12
        ..strokeCap = StrokeCap.round;

      final Path smallWave = Path()..addArc(const Rect.fromLTWH(216, 60, 80, 100), 3.14159, 3.14159);
      canvas.drawPath(smallWave, strokePaint);

      strokePaint.color = white.withValues(alpha: 0.6);
      final Path bigWave = Path()..addArc(const Rect.fromLTWH(186, 30, 140, 100), 3.14159, 3.14159);
      canvas.drawPath(bigWave, strokePaint);
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }
}
