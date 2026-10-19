import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import 'package:ya_viene_pasajero/features/splash/presentation/widgets/fondo_matizado.dart';

import 'helpers/contraste.dart';

/// El fondo del arranque (dueño, 2026-10-18): «texturizado matizado, como
/// azulito con verde suavecito», en vez del blanco liso.
void main() {
  const ancho = 195;
  const alto = 422;

  Future<List<Color>> pintar(WidgetTester tester) async {
    late ByteData datos;
    await tester.runAsync(() async {
      final grabadora = ui.PictureRecorder();
      const PintorMatizado()
          .paint(Canvas(grabadora), Size(ancho.toDouble(), alto.toDouble()));
      final imagen = await grabadora.endRecording().toImage(ancho, alto);
      datos = (await imagen.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    });
    return [
      for (var i = 0; i < ancho * alto; i++)
        Color.fromARGB(datos.getUint8(i * 4 + 3), datos.getUint8(i * 4),
            datos.getUint8(i * 4 + 1), datos.getUint8(i * 4 + 2)),
    ];
  }

  testWidgets('claro en todas partes: la tinta se lee AAA donde sea',
      (tester) async {
    final px = await pintar(tester);
    var peor = double.infinity;
    for (final c in px) {
      expect(c.a, 1, reason: 'el fondo es opaco');
      final r = contraste(AppColors.ink, c);
      if (r < peor) peor = r;
    }
    exigeContraste(peor, 7, 'La tinta sobre el fondo matizado');
  });

  // «Hazlos un poco más claros para que se vean más elegantes y
  // sofisticados» (dueño, 2026-10-18): era 0,81 de luminancia media y 0,66
  // en lo más hondo de una mancha; quedó en 0,87 y 0,76, y luego «devuélvele
  // un poco el color»: a medio camino.
  testWidgets('claro y sutil: el matiz susurra, no pinta', (tester) async {
    final px = await pintar(tester);
    var suma = 0.0, hondo = 1.0;
    for (final c in px) {
      final l = luminancia(c);
      suma += l;
      if (l < hondo) hondo = l;
    }
    expect(suma / px.length, greaterThanOrEqualTo(0.83),
        reason: 'media ${suma / px.length}');
    expect(hondo, greaterThanOrEqualTo(0.7), reason: 'lo más hondo $hondo');
  });

  testWidgets('no es blanco liso: tiene zonas azulitas y verdecitas',
      (tester) async {
    final px = await pintar(tester);
    var azul = 0, verde = 0, blanco = 0;
    for (final c in px) {
      // Umbrales a la medida del matiz (dueño, 2026-10-18: «devuélvele un
      // poco el color»): el tono se nota.
      if (c.b - c.g > 0.022 && c.b - c.r > 0.05) azul++;
      if (c.g - c.b > 0.018 && c.g - c.r > 0.04) verde++;
      if (c.r > 0.99 && c.g > 0.99 && c.b > 0.99) blanco++;
    }
    expect(azul, greaterThan(px.length ~/ 6), reason: 'azul $azul');
    expect(verde, greaterThan(px.length ~/ 6), reason: 'verde $verde');
    expect(blanco, lessThan(px.length ~/ 20), reason: 'blanco $blanco');
  });

  testWidgets('lleva grano: los vecinos no son todos iguales', (tester) async {
    final px = await pintar(tester);
    // En un degradado liso dos vecinos casi nunca difieren en más de un
    // escalón; con grano, muchos sí.
    var saltos = 0;
    for (var y = 0; y < alto; y++) {
      for (var x = 1; x < ancho; x++) {
        final a = px[y * ancho + x], b = px[y * ancho + x - 1];
        if ((luminancia(a) - luminancia(b)).abs() > 0.012) saltos++;
      }
    }
    expect(saltos, greaterThan(ancho * alto ~/ 50), reason: 'saltos $saltos');
  });

  testWidgets('aparece en un fundido corto sobre el blanco nativo',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: FondoMatizado()));
    double opacidad() => tester
        .widget<Opacity>(find.descendant(
            of: find.byType(FondoMatizado), matching: find.byType(Opacity)))
        .opacity;
    expect(opacidad(), 0);
    await tester.pump(FondoMatizado.fundido ~/ 2);
    expect(opacidad(), inExclusiveRange(0, 1));
    await tester.pump(FondoMatizado.fundido);
    expect(opacidad(), 1);
    expect(FondoMatizado.fundido.inMilliseconds, lessThanOrEqualTo(300));
  });

  testWidgets('con «Reducir movimiento» sale entero de una vez',
      (tester) async {
    await tester.pumpWidget(const MediaQuery(
      data: MediaQueryData(disableAnimations: true),
      child: MaterialApp(home: FondoMatizado()),
    ));
    await tester.pump();
    final o = tester.widget<Opacity>(find.descendant(
        of: find.byType(FondoMatizado), matching: find.byType(Opacity)));
    expect(o.opacity, 1);
  });
}
