import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import 'package:ya_viene_pasajero/core/widgets/fondo_malla.dart';
import 'package:ya_viene_pasajero/core/widgets/ink_hero.dart';

import 'helpers/contraste.dart';

/// El fondo del arranque y de la pestaña de Info (dueño, 2026-10-16): una
/// malla de color difuminada, como la de Lifesum, con los colores de la
/// marca. Lo que va encima es blanco, así que se mide sobre los píxeles de
/// verdad, no a ojo.
void main() {
  const pantalla = Size(390, 844);

  /// Pinta la malla y devuelve el color de cada punto pedido.
  Future<Color Function(double x, double y)> pintar(WidgetTester tester) async {
    late ByteData datos;
    await tester.runAsync(() async {
      final grabadora = ui.PictureRecorder();
      FondoMalla.pintor().paint(Canvas(grabadora), pantalla);
      final imagen = await grabadora
          .endRecording()
          .toImage(pantalla.width.toInt(), pantalla.height.toInt());
      datos = (await imagen.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    });
    return (x, y) {
      final i = ((y * pantalla.height).floor() * pantalla.width.toInt() +
              (x * pantalla.width).floor()) *
          4;
      return Color.fromARGB(
          255, datos.getUint8(i), datos.getUint8(i + 1), datos.getUint8(i + 2));
    };
  }

  /// El peor contraste del blanco (a la opacidad dada) en una franja.
  double peorBlanco(Color Function(double, double) en, double x0, double x1,
      double y0, double y1,
      {double alfa = 1}) {
    var peor = double.infinity;
    for (var y = y0; y <= y1; y += 0.01) {
      for (var x = x0; x <= x1; x += 0.02) {
        final fondo = en(x, y);
        final letra =
            Color.alphaBlend(Colors.white.withValues(alpha: alfa), fondo);
        final c = contraste(letra, fondo);
        if (c < peor) peor = c;
      }
    }
    return peor;
  }

  testWidgets('la bajada del arranque se lee en blanco (AA)', (tester) async {
    final en = await pintar(tester);
    // Bajo el logo de 84 (cae entre y=308 y y=391 de 844): el nombre y la
    // bajada, entre 0,47 y 0,58 de alto, centrados.
    // La bajada va en el blanco tenue de `InkHero`, no en blanco pleno.
    expect(peorBlanco(en, 0.25, 0.75, 0.47, 0.58, alfa: InkHero.alfaBajada),
        greaterThanOrEqualTo(4.5));
  });

  testWidgets('el disco verde del logo no se pierde en la malla',
      (tester) async {
    final en = await pintar(tester);
    // Alrededor del disco, a un paso de su borde.
    for (final (x, y) in const [
      (0.5, 0.35),
      (0.34, 0.415),
      (0.66, 0.415),
      (0.5, 0.48),
    ]) {
      expect(contraste(AppColors.primary, en(x, y)), greaterThanOrEqualTo(1.6),
          reason: 'en ($x, $y) el fondo se parece al verde del logo');
    }
  });

  testWidgets('arriba, donde va la cabecera de Info, el blanco grande pasa',
      (tester) async {
    final en = await pintar(tester);
    // El nombre (22, negrita: texto grande) bajo la barra de estado.
    expect(peorBlanco(en, 0.05, 0.95, 0.06, 0.16), greaterThanOrEqualTo(3.0));
  });

  testWidgets('abajo, los créditos chicos en blanco pasan AA', (tester) async {
    final en = await pintar(tester);
    // Sobre la barra de abajo: los créditos del mapa.
    expect(
        peorBlanco(en, 0.1, 0.9, 0.80, 0.86, alfa: FondoMalla.alfaLetraChica),
        greaterThanOrEqualTo(4.5));
  });

  testWidgets('es color, no la tinta plana de antes', (tester) async {
    final en = await pintar(tester);
    final arriba = en(0.1, 0.05);
    final abajo = en(0.9, 0.7);
    // Verde de la marca arriba, azul abajo.
    expect(arriba.g, greaterThan(arriba.b));
    expect(abajo.b, greaterThan(abajo.g));
    expect(arriba, isNot(AppColors.ink));
  });

  testWidgets('abajo también hay verde, no solo azul (dueño, 2026-10-16)',
      (tester) async {
    final en = await pintar(tester);
    // Una esquina de abajo vuelve al verde y la otra se queda en azul: la
    // malla no es un degradado de arriba abajo.
    final abajoIzq = en(0.08, 0.92);
    final abajoDer = en(0.92, 0.92);
    expect(abajoIzq.g, greaterThan(abajoIzq.b + 0.15));
    expect(abajoDer.b, greaterThan(abajoDer.g));
    // Y a media altura, el lado izquierdo tampoco es el mismo que el derecho.
    final medioIzq = en(0.05, 0.66);
    final medioDer = en(0.95, 0.66);
    expect(medioIzq.g - medioIzq.b, greaterThan(medioDer.g - medioDer.b + 0.2));
  });
}
