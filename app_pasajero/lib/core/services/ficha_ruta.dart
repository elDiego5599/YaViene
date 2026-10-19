import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

import '../widgets/ficha_ruta.dart';

/// Lado de la ficha en píxeles. El ícono grande de Android se pinta a 64 dp
/// como mucho; a 3x son 192 px, y iOS reduce la imagen adjunta a su
/// miniatura sin perder nitidez.
const int ladoFicha = 192;

/// La ficha de la ruta para el aviso, la de [FichaRuta] pintada en un PNG,
/// sobre [color] (`colorFicha`).
Future<Uint8List> fichaRuta(String codigo, Color color) async {
  const lado = ladoFicha * 1.0;
  final grabadora = ui.PictureRecorder();
  final lienzo = Canvas(grabadora);
  lienzo.drawRRect(
    RRect.fromRectAndRadius(
      const Rect.fromLTWH(0, 0, lado, lado),
      const Radius.circular(lado * radioFicha),
    ),
    Paint()..color = color,
  );
  final texto = TextPainter(
    text: TextSpan(
      text: codigo,
      // El trazo de la marca (w800, apretado), en píxeles de imagen: la
      // ficha es un mapa de bits fijo, no texto que escale con la pantalla.
      style: AppTextStyles.marca.copyWith(
        fontSize: lado * letraFicha,
        color: const Color(0xFFFFFFFF),
      ),
    ),
    textDirection: TextDirection.ltr,
    maxLines: 1,
  )..layout(maxWidth: lado * 0.88);
  texto.paint(
    lienzo,
    Offset((lado - texto.width) / 2, (lado - texto.height) / 2),
  );
  texto.dispose();
  final imagen = await grabadora.endRecording().toImage(ladoFicha, ladoFicha);
  try {
    final datos = await imagen.toByteData(format: ui.ImageByteFormat.png);
    return datos!.buffer.asUint8List();
  } finally {
    imagen.dispose();
  }
}
