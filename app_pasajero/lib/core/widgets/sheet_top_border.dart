import 'package:flutter/material.dart';

/// El filo de una hoja anclada al borde de abajo: solo arriba.
///
/// Las dos hojas del mapa se dibujaban con `Border.all`. Sobre una tarjeta
/// que va pegada al filo inferior y ocupa todo el ancho, eso pinta tres
/// líneas que nadie pidió: dos bajando por los cantos de la pantalla y una
/// tapada por el propio borde del teléfono. El filo solo tiene trabajo donde
/// la hoja se encuentra con el mapa —el canto de arriba y sus dos hombros—,
/// que es lo único que hay que separar.
class SheetTopBorder extends OutlinedBorder {
  const SheetTopBorder({
    super.side = BorderSide.none,
    this.radio = 32,
  });

  /// Radio de las dos esquinas de arriba.
  final double radio;

  BorderRadius get _radio => BorderRadius.vertical(top: Radius.circular(radio));

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.only(top: side.width);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      Path()..addRRect(_radio.toRRect(rect).deflate(side.width));

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      Path()..addRRect(_radio.toRRect(rect));

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side.style == BorderStyle.none || side.width == 0) return;
    // Medio grosor hacia dentro: un trazo centrado en el borde exacto deja
    // la mitad fuera de la hoja y se ve medio pixel más claro.
    final r = rect.deflate(side.width / 2);
    final radio = this.radio - side.width / 2;
    // Empieza y termina donde los hombros tocan los cantos de la pantalla.
    // No baja por los lados: ahí no hay nada de qué separarse.
    final camino = Path()
      ..moveTo(r.left, r.top + radio)
      ..arcToPoint(
        Offset(r.left + radio, r.top),
        radius: Radius.circular(radio),
      )
      ..lineTo(r.right - radio, r.top)
      ..arcToPoint(
        Offset(r.right, r.top + radio),
        radius: Radius.circular(radio),
      );
    canvas.drawPath(camino, side.toPaint()..style = PaintingStyle.stroke);
  }

  @override
  SheetTopBorder copyWith({BorderSide? side, double? radio}) =>
      SheetTopBorder(side: side ?? this.side, radio: radio ?? this.radio);

  @override
  ShapeBorder scale(double t) =>
      SheetTopBorder(side: side.scale(t), radio: radio * t);
}
