import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import 'package:ya_viene_pasajero/core/widgets/fondo_malla.dart';
import 'package:ya_viene_pasajero/core/widgets/ink_hero.dart';

import 'helpers/contraste.dart';

/// El fondo de la bienvenida (dueño, 2026-10-16): una
/// malla de color difuminada, como la de Lifesum, con los colores de la
/// marca. Lo que va encima es blanco, así que se mide sobre los píxeles de
/// verdad, no a ojo.
void main() {
  const pantalla = Size(390, 844);

  /// Pinta la malla y devuelve el color de cada punto pedido.
  Future<Color Function(double x, double y)> pintar(WidgetTester tester,
      {double fase = 0}) async {
    late ByteData datos;
    await tester.runAsync(() async {
      final grabadora = ui.PictureRecorder();
      FondoMalla.pintor(fase: fase).paint(Canvas(grabadora), pantalla);
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

  // La malla respira (dueño, 2026-10-16): lo que se mide tiene que valer en
  // todo el ciclo, no solo en la foto de arranque.
  const fases = [0.0, 0.125, 0.25, 0.375, 0.5, 0.625, 0.75, 0.875];

  testWidgets('la bajada del arranque se lee en blanco (AA)', (tester) async {
    for (final fase in fases) {
      final en = await pintar(tester, fase: fase);
      // Bajo el logo de 84 (cae entre y=308 y y=391 de 844): el nombre y la
      // bajada, entre 0,47 y 0,58 de alto, centrados.
      // La bajada va en el blanco tenue de `InkHero`, no en blanco pleno.
      expect(peorBlanco(en, 0.25, 0.75, 0.47, 0.58, alfa: InkHero.alfaBajada),
          greaterThanOrEqualTo(4.5),
          reason: 'fase $fase');
    }
  });

  testWidgets('el disco verde del logo no se pierde en la malla',
      (tester) async {
    for (final fase in fases) {
      final en = await pintar(tester, fase: fase);
      // Alrededor del disco, a un paso de su borde.
      for (final (x, y) in const [
        (0.5, 0.35),
        (0.34, 0.415),
        (0.66, 0.415),
        (0.5, 0.48),
      ]) {
        expect(
            contraste(AppColors.primary, en(x, y)), greaterThanOrEqualTo(1.6),
            reason: 'en ($x, $y), fase $fase, el fondo se parece al verde');
      }
    }
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

  Future<void> montar(WidgetTester tester, {bool reducido = false}) async {
    await tester.pumpWidget(MediaQuery(
      data: MediaQueryData(disableAnimations: reducido),
      child: const Directionality(
        textDirection: TextDirection.ltr,
        child: FondoMalla(child: SizedBox()),
      ),
    ));
  }

  double faseEnPantalla(WidgetTester tester) => tester
      .widgetList<CustomPaint>(find.byType(CustomPaint))
      .map((c) => c.painter)
      .whereType<PintorMalla>()
      .single
      .fase;

  // «Que no fuera un fondo estático, que parezca moverse y respirar»
  // (dueño, 2026-10-16).
  testWidgets('arranca en la misma foto que la pantalla nativa',
      (tester) async {
    await montar(tester);
    expect(faseEnPantalla(tester), 0);
  });

  testWidgets('respira: se mueve con el tiempo y vuelve a empezar',
      (tester) async {
    await montar(tester);
    await tester.pump(FondoMalla.vuelta * 0.25);
    expect(faseEnPantalla(tester), closeTo(0.25, 0.01));
    await tester.pump(FondoMalla.vuelta * 0.8);
    expect(faseEnPantalla(tester), closeTo(0.05, 0.01));
  });

  testWidgets('con «Reducir movimiento» se queda quieta', (tester) async {
    await montar(tester, reducido: true);
    await tester.pump(FondoMalla.vuelta * 0.25);
    expect(faseEnPantalla(tester), 0);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('el ciclo no salta: la última foto es la primera',
      (tester) async {
    final inicio = await pintar(tester);
    final fin = await pintar(tester, fase: 0.999);
    for (final (x, y) in const [(0.1, 0.1), (0.5, 0.5), (0.9, 0.9)]) {
      final a = inicio(x, y);
      final b = fin(x, y);
      expect((a.r - b.r).abs() + (a.g - b.g).abs() + (a.b - b.b).abs(),
          lessThan(0.02));
    }
  });

  testWidgets('a media vuelta la malla es otra', (tester) async {
    final inicio = await pintar(tester);
    final medio = await pintar(tester, fase: 0.5);
    var diferencia = 0.0;
    for (final (x, y) in const [(0.2, 0.3), (0.8, 0.5), (0.3, 0.8)]) {
      final a = inicio(x, y);
      final b = medio(x, y);
      diferencia += (a.r - b.r).abs() + (a.g - b.g).abs() + (a.b - b.b).abs();
    }
    expect(diferencia, greaterThan(0.06));
  });
}
