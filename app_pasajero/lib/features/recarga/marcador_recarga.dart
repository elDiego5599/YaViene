import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// El morado de los puntos de recarga. Ningún otro elemento del mapa lo usa:
/// el azul es de la ubicación, el verde de la ruta y el rojo de los buses,
/// así un punto de recarga nunca se confunde con ninguno. 9,36:1 con el
/// blanco del glifo y 8,37:1 con el papel del mapa (#F4F2EE).
const Color moradoRecarga = Color(0xFF5B2E91);

/// El marcador de un punto de recarga: una insignia cuadrada de esquinas
/// redondas (como los de Transit, y a diferencia del círculo de la ubicación)
/// con una tarjeta de transporte dentro. Lo pintan igual el mapa y el
/// medallón de la ficha, para que lo que se toca y lo que se lee sea lo
/// mismo.
class MarcadorRecargaPainter extends CustomPainter {
  const MarcadorRecargaPainter({this.sombra = true});

  /// El mapa lleva sombra suave bajo la insignia; el medallón de la ficha no.
  final bool sombra;

  @override
  void paint(Canvas canvas, Size size) {
    final lado = size.shortestSide;
    final centro = size.center(Offset.zero);
    // La insignia ocupa 0,86 del lienzo: el resto es el aire de la sombra.
    final insignia = Rect.fromCenter(
        center: centro, width: lado * 0.86, height: lado * 0.86);
    final forma =
        RRect.fromRectAndRadius(insignia, Radius.circular(lado * 0.26));

    if (sombra) {
      canvas.drawRRect(
        forma.shift(Offset(0, lado * 0.035)),
        Paint()
          ..color = const Color(0xFF17325F).withValues(alpha: 0.28)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, lado * 0.045),
      );
    }
    canvas.drawRRect(forma, Paint()..color = moradoRecarga);
    // Filo blanco por dentro del borde: despega la insignia del mapa.
    canvas.drawRRect(
      forma.deflate(lado * 0.03),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = lado * 0.06
        ..color = Colors.white,
    );

    // La tarjeta: 0,50 x 0,34 del lienzo, con su banda y dos rayas de texto.
    final tarjeta = Rect.fromCenter(
        center: centro.translate(0, lado * 0.01),
        width: lado * 0.50,
        height: lado * 0.34);
    final cuerpo =
        RRect.fromRectAndRadius(tarjeta, Radius.circular(lado * 0.055));
    canvas.drawRRect(cuerpo, Paint()..color = Colors.white);
    canvas.save();
    canvas.clipRRect(cuerpo);
    canvas.drawRect(
      Rect.fromLTWH(tarjeta.left, tarjeta.top + tarjeta.height * 0.16,
          tarjeta.width, tarjeta.height * 0.22),
      Paint()..color = moradoRecarga,
    );
    canvas.restore();
    final raya = Paint()
      ..color = moradoRecarga
      ..strokeCap = StrokeCap.round
      ..strokeWidth = lado * 0.04;
    final y = tarjeta.top + tarjeta.height * 0.72;
    canvas.drawLine(Offset(tarjeta.left + tarjeta.width * 0.14, y),
        Offset(tarjeta.left + tarjeta.width * 0.46, y), raya);
    canvas.drawLine(Offset(tarjeta.left + tarjeta.width * 0.56, y),
        Offset(tarjeta.left + tarjeta.width * 0.70, y), raya);
  }

  @override
  bool shouldRepaint(MarcadorRecargaPainter old) => old.sombra != sombra;
}

/// Lado lógico del lienzo del marcador en el mapa, en puntos.
const double ladoMarcadorRecarga = 36;

/// Con cuántos píxeles por punto se rasteriza: 3, como los iPhone.
const double escalaMarcadorRecarga = 3;

/// El marcador como PNG para dárselo a MapLibre (`addImage`).
Future<Uint8List> pintarMarcadorRecarga() async {
  const px = ladoMarcadorRecarga * escalaMarcadorRecarga;
  final grabadora = ui.PictureRecorder();
  const MarcadorRecargaPainter().paint(Canvas(grabadora), const Size(px, px));
  final imagen = await grabadora.endRecording().toImage(px.round(), px.round());
  final datos = await imagen.toByteData(format: ui.ImageByteFormat.png);
  return datos!.buffer.asUint8List();
}
