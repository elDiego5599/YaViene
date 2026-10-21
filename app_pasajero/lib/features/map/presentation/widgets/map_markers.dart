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
  // El lienzo se duplica (96 → 192 px) y el mismo dibujo se escala: MapLibre
  // conserva el tamaño en pantalla, pero las ventanas y filos no se hornean
  // a resolución baja.
  const size = 192;
  final pictureRecorder = ui.PictureRecorder();
  final canvas = Canvas(pictureRecorder);
  canvas.scale(2);
  drawTransitBus(canvas, const Rect.fromLTWH(31, 8, 34, 80), baseColor,
      isGhost: isGhost);
  final img = await pictureRecorder.endRecording().toImage(size, size);
  final data = await img.toByteData(format: ui.ImageByteFormat.png);
  return data?.buffer.asUint8List() ?? Uint8List(0);
}

/// Pinta el bus cenital en [bounds]. El frente mira al borde superior: rumbo
/// 0 de MapLibre es norte. También lo usa la seña para que el espejo no derive.
void drawTransitBus(Canvas canvas, Rect bounds, Color baseColor,
    {required bool isGhost}) {
  canvas.save();
  canvas.translate(bounds.left, bounds.top);
  canvas.scale(bounds.width / 34, bounds.height / 80);
  const body = Rect.fromLTWH(0, 0, 34, 80);
  final shell =
      RRect.fromRectAndRadius(body, const Radius.circular(AppRadius.sm));

  if (!isGhost) {
    // Sombra gris de contacto, centrada y sin dirección: al girar con el
    // rumbo del mapa no queda detrás del bus ni se convierte en una estela.
    canvas.drawRRect(
        shell,
        Paint()
          ..color = const Color(0xFF30343B).withValues(alpha: 0.30)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.2));
  }

  final topLeft = isGhost
      ? Color.lerp(baseColor, Colors.white, 0.12)!
      : Color.lerp(baseColor, Colors.white, 0.34)!;
  final sideDark = isGhost
      ? Color.lerp(baseColor, Colors.black, 0.08)!
      : Color.lerp(baseColor, Colors.black, 0.25)!;
  canvas.drawRRect(
      shell,
      Paint()
        ..shader = ui.Gradient.linear(const Offset(0, 0), const Offset(34, 0),
            [topLeft, baseColor, sideDark], const [0.0, 0.58, 1.0]));

  // Filo de 1,3 unidades (2,6 px ya horneados): a zoom 13 son 0,42 pt
  // sobre el bus de 26 pt, suficiente para separarlo de CARTO Voyager.
  canvas.drawRRect(
      shell,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3
        ..color = Colors.white.withValues(alpha: isGhost ? 0.48 : 0.94));

  if (!isGhost) {
    canvas.save();
    canvas.clipRRect(shell);
    // Parabrisas delantero: banda ancha de vidrio oscuro, con reflejo arriba.
    final windshield = RRect.fromRectAndRadius(
        const Rect.fromLTWH(4, 5, 26, 15),
        const Radius.circular(AppRadius.busParabrisas));
    canvas.drawRRect(
        windshield,
        Paint()
          ..shader = ui.Gradient.linear(
              const Offset(7, 5),
              const Offset(27, 20),
              const [Color(0xFF172936), Color(0xFF344D5C)]));
    canvas.drawRRect(
        RRect.fromRectAndRadius(const Rect.fromLTWH(7, 7, 12, 2),
            const Radius.circular(AppRadius.busBrillo)),
        Paint()..color = Colors.white.withValues(alpha: 0.48));
    // Luneta trasera menor, separada del frente por el techo rojo.
    canvas.drawRRect(
        RRect.fromRectAndRadius(const Rect.fromLTWH(8, 67, 18, 7),
            const Radius.circular(AppRadius.busLuneta)),
        Paint()..color = const Color(0xFF253A47));
    // Dos equipos bajos de aire en el techo, con lamas discretas.
    for (final y in [28.0, 40.0]) {
      final hatch = RRect.fromRectAndRadius(Rect.fromLTWH(7, y, 20, 8),
          const Radius.circular(AppRadius.busEscotilla));
      canvas.drawRRect(hatch, Paint()..color = sideDark);
      for (final lineY in [y + 2.0, y + 4.0, y + 6.0]) {
        canvas.drawLine(
            Offset(10, lineY),
            Offset(24, lineY),
            Paint()
              ..color = Colors.white.withValues(alpha: 0.20)
              ..strokeWidth = 0.8);
      }
    }
    // Luces delanteras pequeñas y cálidas, una a cada lado del parabrisas.
    for (final x in [4.0, 30.0]) {
      canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(x - 1.1, 2, 2.2, 3),
              const Radius.circular(AppRadius.busBrillo)),
          Paint()..color = const Color(0xFFFFF2C2));
    }
    canvas.restore();
  } else {
    // El fantasma conserva la carrocería, pero queda plano y sin sombra.
    canvas.drawRRect(
        RRect.fromRectAndRadius(const Rect.fromLTWH(7, 9, 20, 62),
            const Radius.circular(AppRadius.busFantasma)),
        Paint()..color = Colors.white.withValues(alpha: 0.10));
  }
  canvas.restore();
}
