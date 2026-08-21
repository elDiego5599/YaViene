// Iconos del mapa: pin del usuario y buses. Antes vivían dentro de
// map_widget.dart; ahora tienen su propio archivo para encontrarlos rápido.
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

const kBusIconId = 'bus-icon-active';
const kBusGhostIconId = 'bus-icon-ghost';
const kUserPinIconId = 'user-pin-icon';

Future<void> loadBusIcons(MapLibreMapController? controller) async {
  if (controller == null) return;
  try {
    final activeBytes = await createFlatTransitMarker(
      const Color(0xFF14274E),
      isGhost: false,
    );
    final ghostBytes = await createFlatTransitMarker(
      const Color(0xFF94A3B8),
      isGhost: true,
    );
    await controller.addImage(kBusIconId, activeBytes);
    await controller.addImage(kBusGhostIconId, ghostBytes);
    await controller.addImage(kUserPinIconId, await createPinMarker());
  } catch (e) {
    debugPrint('Error generando iconos Flat: $e');
  }
}

Future<Uint8List> createPinMarker() async {
  const size = 80;
  const centerX = size / 2;
  const headCY = 30.0;
  const headR = 26.0;
  const tipY = 76.0;
  final pictureRecorder = ui.PictureRecorder();
  final canvas = Canvas(pictureRecorder);

  final dropPath = Path()
    ..moveTo(centerX, tipY)
    ..quadraticBezierTo(centerX - 30, tipY - 28, centerX - headR, headCY)
    ..arcTo(
      Rect.fromCircle(center: const Offset(centerX, headCY), radius: headR),
      math.pi,
      math.pi,
      false,
    )
    ..quadraticBezierTo(centerX + 30, tipY - 28, centerX, tipY);

  canvas.drawShadow(
    dropPath,
    Colors.black.withValues(alpha: 0.25),
    6.0,
    false,
  );

  final dropPaint = Paint()
    ..shader = ui.Gradient.linear(
      const Offset(centerX, 4),
      const Offset(centerX, tipY),
      const [Color(0xFF4ADE80), Color(0xFF059669)],
    );
  canvas.drawPath(dropPath, dropPaint);

  canvas.drawOval(
    Rect.fromCenter(
      center: const Offset(centerX, headCY - 16),
      width: 24,
      height: 9,
    ),
    Paint()..color = Colors.white.withValues(alpha: 0.20),
  );

  canvas.drawCircle(
    const Offset(centerX, headCY),
    12.5,
    Paint()..color = Colors.white,
  );
  canvas.drawCircle(
    const Offset(centerX, headCY),
    8.5,
    Paint()
      ..shader = ui.Gradient.linear(
        const Offset(centerX - 9, headCY - 9),
        const Offset(centerX + 9, headCY + 9),
        const [Color(0xFF065F46), Color(0xFF00A859)],
      ),
  );
  canvas.drawCircle(
    const Offset(centerX - 2.5, headCY - 3),
    2.2,
    Paint()..color = Colors.white.withValues(alpha: 0.85),
  );

  final img = await pictureRecorder.endRecording().toImage(size, size);
  final data = await img.toByteData(format: ui.ImageByteFormat.png);
  return data?.buffer.asUint8List() ?? Uint8List(0);
}

Future<Uint8List> createFlatTransitMarker(
  Color baseColor, {
  required bool isGhost,
}) async {
  const size = 80;
  const centerX = size / 2;
  const centerY = size / 2;
  final pictureRecorder = ui.PictureRecorder();
  final canvas = Canvas(pictureRecorder);

  final shadowPath = Path()
    ..addRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: const Offset(centerX, centerY + 2),
          width: 32,
          height: 60,
        ),
        const Radius.circular(10),
      ),
    );
  canvas.drawShadow(
    shadowPath,
    Colors.black.withValues(alpha: 0.15),
    4.0,
    false,
  );

  final bodyPaint = Paint()
    ..color = baseColor
    ..style = PaintingStyle.fill;
  final bodyRect = RRect.fromRectAndRadius(
    Rect.fromCenter(
      center: const Offset(centerX, centerY),
      width: 32,
      height: 60,
    ),
    const Radius.circular(10),
  );
  canvas.drawRRect(bodyRect, bodyPaint);

  final glassPaint = Paint()
    ..color = Colors.white.withValues(alpha: isGhost ? 0.5 : 0.95)
    ..style = PaintingStyle.fill;
  final glassRect = RRect.fromRectAndRadius(
    Rect.fromCenter(
      center: const Offset(centerX, centerY - 18),
      width: 24,
      height: 10,
    ),
    const Radius.circular(4),
  );
  canvas.drawRRect(glassRect, glassPaint);

  if (!isGhost) {
    final headlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      const Offset(centerX - 9, centerY - 23),
      2.4,
      headlightPaint,
    );
    canvas.drawCircle(
      const Offset(centerX + 9, centerY - 23),
      2.4,
      headlightPaint,
    );
  }

  final img = await pictureRecorder.endRecording().toImage(size, size);
  final data = await img.toByteData(format: ui.ImageByteFormat.png);
  return data?.buffer.asUint8List() ?? Uint8List(0);
}
