import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

class MarkerGenerator {
  static Future<Uint8List> generateBusMarker({bool isGhost = false}) async {
    const double size = 60;
    const Offset center = Offset(size / 2, size / 2);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final Color fillColor =
        isGhost ? const Color(0xFF94A3B8) : const Color(0xFF14274E);
    const Color white = Color(0xFFFFFFFF);

    final shadowPaint = Paint()
      ..color = const Color(0xFF14274E).withValues(alpha: isGhost ? 0.08 : 0.16)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    canvas.drawCircle(center.translate(0, 2), 23, shadowPaint);

    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 22, fillPaint);

    final borderPaint = Paint()
      ..color = white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(center, 22, borderPaint);

    final arrowPaint = Paint()
      ..color = white
      ..style = PaintingStyle.fill;
    final arrowPath = Path()
      ..moveTo(center.dx, 9)
      ..lineTo(center.dx - 5, 20)
      ..lineTo(center.dx + 5, 20)
      ..close();
    canvas.drawPath(arrowPath, arrowPaint);

    final iconPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(Icons.directions_bus_rounded.codePoint),
        style: TextStyle(
          inherit: false,
          color: white,
          fontSize: 22,
          fontFamily: Icons.directions_bus_rounded.fontFamily,
          package: Icons.directions_bus_rounded.fontPackage,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    iconPainter.paint(
      canvas,
      Offset(
        center.dx - iconPainter.width / 2,
        center.dy - iconPainter.height / 2 + 5,
      ),
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }
}
