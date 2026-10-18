import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_pasajero/features/mas/presentation/fondo_mosaico.dart';

import 'helpers/contraste.dart';

/// El fondo de Info (dueño, 2026-10-18): un mosaico de dibujos de línea
/// —«Cartoon Doodle Wall»— con lo de Barranquilla: la Ventana al Mundo, la
/// cayena, los buses de las cuatro empresas, la marimonda, la palmera, el
/// sol y el Puente Pumarejo. Claro y quieto.
void main() {
  const pantalla = Size(390, 844);

  testWidgets('trae los diez dibujos y todos caben en un teléfono',
      (tester) async {
    expect(Motivo.values, hasLength(10));
    final vistos = {
      for (final (m, centro) in PintorMosaico.celdas(pantalla))
        if ((Offset.zero & pantalla).contains(centro)) m,
    };
    expect(vistos, Motivo.values.toSet());
  });

  testWidgets('dos vecinos nunca repiten dibujo', (tester) async {
    final celdas = PintorMosaico.celdas(pantalla).toList();
    var pares = 0;
    for (final (a, ca) in celdas) {
      for (final (b, cb) in celdas) {
        final d = (ca - cb).distance;
        if (d == 0 || d > PintorMosaico.celda * 1.3) continue;
        pares++;
        expect(a, isNot(b), reason: 'en $ca y $cb');
      }
    }
    expect(pares, greaterThan(100));
  });

  Future<List<Color>> pintar(WidgetTester tester) async {
    final ancho = pantalla.width.toInt(), alto = pantalla.height.toInt();
    late ByteData datos;
    await tester.runAsync(() async {
      final grabadora = ui.PictureRecorder();
      const PintorMosaico().paint(Canvas(grabadora), pantalla);
      final imagen = await grabadora.endRecording().toImage(ancho, alto);
      datos = (await imagen.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    });
    return [
      for (var i = 0; i < ancho * alto; i++)
        Color.fromARGB(datos.getUint8(i * 4 + 3), datos.getUint8(i * 4),
            datos.getUint8(i * 4 + 1), datos.getUint8(i * 4 + 2)),
    ];
  }

  testWidgets('con color, pero claro: no le gana a las tarjetas',
      (tester) async {
    final px = await pintar(tester);
    var suma = 0.0, oscuro = 1.0, conColor = 0;
    for (final c in px) {
      expect(c.a, 1, reason: 'el fondo es opaco');
      final l = luminancia(c);
      suma += l;
      if (l < oscuro) oscuro = l;
      if (HSLColor.fromColor(c).saturation > 0.35) conColor++;
    }
    // Casi todo es papel; el trazo más oscuro sigue siendo un tono medio,
    // lejos de la tinta de la letra.
    expect(suma / px.length, greaterThan(0.85));
    expect(oscuro, greaterThan(0.25), reason: 'oscuro $oscuro');
    // Y hay dibujos de colores, no un gris.
    expect(conColor, greaterThan(px.length ~/ 25), reason: 'color $conColor');
  });

  testWidgets('quieto: no pide cuadros ni se vuelve a pintar', (tester) async {
    await tester
        .pumpWidget(const MaterialApp(home: FondoMosaico(child: SizedBox())));
    // El primer cuadro de MaterialApp pide otro; después, nada.
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(const PintorMosaico().shouldRepaint(const PintorMosaico()), isFalse);
  });
}
