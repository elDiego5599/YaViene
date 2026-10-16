import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_pasajero/core/widgets/fondo_malla.dart';

/// Las pantallas de arranque nativas (el storyboard de iOS y el
/// `launch_background.xml` de Android) no pueden pintar la malla: la llevan
/// como imagen. Esa imagen sale de este mismo pintor, así que si la malla
/// cambia y nadie regenera los PNG, el relevo nativa → Flutter salta de
/// color y esta prueba lo dice. Para regenerarlos:
/// `flutter test --update-goldens test/fondo_malla_nativo_test.dart`.
void main() {
  // Una pantalla de 390×844 a 1x: se estira a cualquier teléfono sin que se
  // note, porque la malla no tiene bordes que pixelar. A 2x pesaba 834 KB
  // por plataforma para verse igual.
  const tamano = Size(390, 844);

  Future<void> pintar(WidgetTester tester) async {
    tester.view.physicalSize = tamano;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      RepaintBoundary(
        child: CustomPaint(painter: FondoMalla.pintor(), size: tamano),
      ),
    );
  }

  testWidgets('la de iOS es la misma malla', (tester) async {
    await pintar(tester);
    await expectLater(
      find.byType(RepaintBoundary).first,
      matchesGoldenFile(
          '../ios/Runner/Assets.xcassets/FondoMalla.imageset/fondo_malla.png'),
    );
  });

  testWidgets('la de Android es la misma malla', (tester) async {
    await pintar(tester);
    await expectLater(
      find.byType(RepaintBoundary).first,
      matchesGoldenFile(
          '../android/app/src/main/res/drawable-nodpi/fondo_malla.png'),
    );
  });

  // El logo del arranque de iOS se pinta sobre la malla: si su PNG no trae
  // transparencia, las esquinas del cuadrado salen en el color con que se
  // exportó y el disco verde queda metido en un cuadro (dueño, 2026-10-16).
  for (final escala in ['', '@2x', '@3x']) {
    testWidgets('el logo del arranque de iOS$escala no trae cuadro',
        (tester) async {
      final bytes = File('ios/Runner/Assets.xcassets/LaunchImage.imageset/'
              'LaunchImage$escala.png')
          .readAsBytesSync();
      final pixeles = await tester.runAsync(() async {
        final codec = await ui.instantiateImageCodec(bytes);
        final imagen = (await codec.getNextFrame()).image;
        final datos =
            await imagen.toByteData(format: ui.ImageByteFormat.rawRgba);
        return (imagen.width, datos!);
      });
      final (ancho, datos) = pixeles!;
      // La esquina de arriba a la izquierda, fuera del disco.
      expect(datos.getUint8(3), 0, reason: 'esquina opaca');
      // El centro, dentro del disco, sí se ve.
      final centro = ((ancho ~/ 2) * ancho + ancho ~/ 2) * 4;
      expect(datos.getUint8(centro + 3), 255);
    });
  }
}
