import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_pasajero/features/mas/presentation/fondo_ilustrado.dart';
import 'package:ya_viene_pasajero/features/splash/presentation/widgets/escena_arranque.dart';
import 'package:ya_viene_pasajero/features/splash/presentation/widgets/fondo_matizado.dart';

/// El fondo de Info (dueño, 2026-10-18: «mejor con las fotos animadas, que
/// se ven bien detalladas y bonitas, le darán un look más elegante», y luego
/// el sol y la palmera): pocas
/// ilustraciones grandes de Barranquilla, sueltas en las orillas, sobre el
/// matizado del arranque. Quieto.
void main() {
  const pantalla = Size(390, 844);

  testWidgets('son ilustraciones que existen, livianas y en su proporción',
      (tester) async {
    expect(FondoIlustrado.piezas.length, inInclusiveRange(6, 8));
    var bytes = 0;
    for (final p in FondoIlustrado.piezas) {
      if (p.asset == null) continue;
      final archivo = File(p.asset!);
      expect(archivo.existsSync(), isTrue, reason: p.asset);
      bytes += archivo.lengthSync();
      // La proporción escrita en el código es la del archivo: si se cambia
      // la ilustración, la cuenta de dónde cae se cambia con ella.
      late ui.Image imagen;
      await tester.runAsync(() async {
        final codec = await ui.instantiateImageCodec(archivo.readAsBytesSync());
        imagen = (await codec.getNextFrame()).image;
      });
      expect(imagen.height / imagen.width, closeTo(p.proporcion, 0.01),
          reason: p.asset);
      // Nítidas en un iPhone (@3x) al ancho al que se pintan.
      expect(imagen.width, greaterThanOrEqualTo(p.ancho * pantalla.width * 2.5),
          reason: p.asset);
    }
    expect(bytes, lessThan(200 * 1024), reason: '$bytes bytes');
  });

  // «Usa la misma Ventana al Mundo que en la pantalla de carga» (dueño,
  // 2026-10-18): la torre es la del arranque, entera, no una foto aparte.
  testWidgets('la Ventana al Mundo es la del arranque, ya armada',
      (tester) async {
    final torre = FondoIlustrado.piezas.where((p) => p.asset == null);
    expect(torre, hasLength(1));
    expect(torre.single.proporcion, 1 / PintorVentana.aspecto);
    await tester
        .pumpWidget(const MaterialApp(home: FondoIlustrado(child: SizedBox())));
    final pintores = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((c) => c.painter)
        .whereType<PintorVentana>();
    // La torre y su sombra.
    expect(pintores, hasLength(2));
    expect(pintores.every((p) => p.avance == 1), isTrue);
  });

  testWidgets('se asoman por las orillas sin pisarse entre ellas',
      (tester) async {
    final todo = Offset.zero & pantalla;
    final rects = [
      for (final p in FondoIlustrado.piezas) p.rectEn(pantalla),
    ];
    for (final (i, r) in rects.indexed) {
      final dentro = r.intersect(todo);
      final visible = dentro.width * dentro.height / (r.width * r.height);
      expect(visible, inInclusiveRange(0.4, 1.0),
          reason: '${FondoIlustrado.piezas[i].asset} $visible');
    }
    for (var i = 0; i < rects.length; i++) {
      for (var j = i + 1; j < rects.length; j++) {
        final c = rects[i].intersect(rects[j]);
        final cruce = c.width <= 0 || c.height <= 0 ? 0.0 : c.width * c.height;
        final menor = [rects[i], rects[j]]
            .map((r) => r.width * r.height)
            .reduce((a, b) => a < b ? a : b);
        expect(cruce / menor, lessThan(0.06),
            reason: '${FondoIlustrado.piezas[i].asset} y '
                '${FondoIlustrado.piezas[j].asset}');
      }
    }
  });

  testWidgets('van sobre el matizado del arranque, sin anunciarse',
      (tester) async {
    await tester
        .pumpWidget(const MaterialApp(home: FondoIlustrado(child: SizedBox())));
    expect(
        find.byWidgetPredicate(
            (w) => w is CustomPaint && w.painter is PintorMatizado),
        findsOneWidget);
    final imagenes = tester.widgetList<Image>(find.byType(Image)).toList();
    // Cada ilustración con su sombra.
    expect(
        imagenes,
        hasLength(
            FondoIlustrado.piezas.where((p) => p.asset != null).length * 2));
    // Decorativas: el lector de pantalla no lee «imagen» cinco veces.
    expect(imagenes.every((i) => i.excludeFromSemantics), isTrue);
  });

  testWidgets('quieto: no pide cuadros', (tester) async {
    await tester
        .pumpWidget(const MaterialApp(home: FondoIlustrado(child: SizedBox())));
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isFalse);
  });
}
