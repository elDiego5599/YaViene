// Iconos del mapa: pin del usuario y buses. Antes vivían dentro de
// map_widget.dart; ahora tienen su propio archivo para encontrarlos rápido.
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

const kBusIconId = 'bus-icon-active';
const kBusGhostIconId = 'bus-icon-ghost';
const kUserPinIconId = 'user-pin-icon';

Future<void> loadBusIcons(MapLibreMapController? controller) async {
  if (controller == null) return;
  try {
    final activeBytes = await createFlatTransitMarker(
      AppColors.busActive,
      isGhost: false,
    );
    final ghostBytes = await createFlatTransitMarker(
      AppColors.textDisabled,
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
        const [Color(0xFF065F46), AppColors.primary],
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
  // Silueta alargada tipo inDrive/Uber: una cápsula de un solo color, sin
  // ventanas ni llantas — el detalle se pierde a los ~28px reales en el
  // mapa, así que la forma y el color son todo lo que tiene que comunicar.
  // Se hornea una sola vez por ícono y se reusa como sprite nativo de
  // MapLibre para cada bus en pantalla.
  const size = 96;
  const center = size / 2.0;
  const w = 32.0;
  const h = 60.0;

  final pictureRecorder = ui.PictureRecorder();
  final canvas = Canvas(pictureRecorder);

  final capsule = RRect.fromRectAndRadius(
    const Rect.fromLTWH(center - w / 2, center - h / 2, w, h),
    const Radius.circular(w / 2),
  );

  if (!isGhost) {
    // Sombra de contacto: gris, corta y centrada, la de un objeto que se
    // posa sobre el mapa. Antes era del color del bus y corrida 3 hacia
    // abajo, y como el ícono gira con el rumbo (`iconRotationAlignment:
    // 'map'`), ese «abajo» quedaba detrás del bus según a dónde fuera: una
    // estela roja que al dueño le pareció rarísima (2026-09-30). Centrada
    // no tiene dirección, así que gire como gire el bus se ve igual. El
    // desenfoque de 2,4 (h × 0,04) despega la cápsula sin ensuciar la
    // calle; a 1,254 de escala son 3 puntos en pantalla.
    canvas.drawRRect(
      capsule,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.24)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, h * 0.04),
    );
  }

  // Degradado sutil (más claro arriba) para que no se vea una silueta plana.
  final top = isGhost ? baseColor : Color.lerp(baseColor, Colors.white, 0.3)!;
  canvas.drawRRect(
    capsule,
    Paint()
      ..shader = ui.Gradient.linear(
        const Offset(center, center - h / 2),
        const Offset(center, center + h / 2),
        [top, baseColor],
      ),
  );

  // Anillo blanco: separa el ícono de cualquier fondo de mapa.
  canvas.drawRRect(
    capsule,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..color = Colors.white.withValues(alpha: isGhost ? 0.5 : 0.92),
  );

  if (!isGhost) {
    // Insinúa un parabrisas: un óvalo tenue cerca del extremo, nada más.
    canvas.save();
    canvas.clipRRect(capsule);
    canvas.drawOval(
      Rect.fromCenter(
        center: const Offset(center, center - h * 0.26),
        width: w * 0.72,
        height: h * 0.26,
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.3),
    );
    canvas.restore();
  }

  final img = await pictureRecorder.endRecording().toImage(size, size);
  final data = await img.toByteData(format: ui.ImageByteFormat.png);
  return data?.buffer.asUint8List() ?? Uint8List(0);
}
