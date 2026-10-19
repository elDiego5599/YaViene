import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

/// Lado de la ficha en píxeles. El ícono grande de Android se pinta a 64 dp
/// como mucho; a 3x son 192 px, y iOS reduce la imagen adjunta a su
/// miniatura sin perder nitidez.
const int ladoFicha = 192;

/// La ficha de la ruta para el aviso: un cuadro redondeado azul de botón
/// (#1E56A8, `AppColors.acento`) con el código en blanco, que contrasta
/// 7,1:1. Devuelve el PNG.
Future<Uint8List> fichaRuta(String codigo) async {
  const lado = ladoFicha * 1.0;
  final grabadora = ui.PictureRecorder();
  final lienzo = Canvas(grabadora);
  // Radio de 22 %, el de los íconos de app, para que no parezca un botón.
  lienzo.drawRRect(
    RRect.fromRectAndRadius(
      const Rect.fromLTWH(0, 0, lado, lado),
      const Radius.circular(lado * 0.22),
    ),
    Paint()..color = AppColors.acento,
  );
  // A 0,4 del lado (77 px) tres caracteres (B18) caben con aire; uno o dos
  // se quedan en ese tamaño para que todas las fichas se lean igual.
  final texto = TextPainter(
    text: TextSpan(
      text: codigo,
      // El trazo de la marca (w800, apretado), en píxeles de imagen: la
      // ficha es un mapa de bits fijo, no texto que escale con la pantalla.
      style: AppTextStyles.marca.copyWith(
        fontSize: lado * 0.4,
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
