import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

/// El bus del arranque es de Ya Viene, no de una empresa (dueño,
/// 2026-10-18): con «SOBUSA» en grande la app parecía exclusiva de Sobusa.
/// Quedan el letrero de Barranquilla, el verde y las franjas de la bandera
/// de la ciudad; salen el nombre del parabrisas y la insignia de la parrilla.
void main() {
  late ByteData px;
  late int ancho;

  setUpAll(() async {
    final bytes = File('assets/images/arranque_bus.webp').readAsBytesSync();
    final codec = await ui.instantiateImageCodec(bytes);
    final imagen = (await codec.getNextFrame()).image;
    ancho = imagen.width;
    px = (await imagen.toByteData())!;
  });

  /// Cuántos píxeles de la caja cumplen [prueba] sobre (r, g, b).
  int contar(int x0, int y0, int x1, int y1, bool Function(int, int, int) p) {
    var n = 0;
    for (var y = y0; y < y1; y++) {
      for (var x = x0; x < x1; x++) {
        final i = (y * ancho + x) * 4;
        if (p(px.getUint8(i), px.getUint8(i + 1), px.getUint8(i + 2))) n++;
      }
    }
    return n;
  }

  test('el parabrisas no lleva el nombre de una empresa', () {
    // La franja alta del vidrio, donde iba «SOBUSA» en blanco.
    final blancos =
        contar(50, 42, 168, 70, (r, g, b) => r > 200 && g > 200 && b > 200);
    expect(blancos, lessThan(10));
  });

  test('la parrilla no lleva insignia', () {
    // Los listones son horizontales: cada fila del centro de la parrilla
    // va pareja de lado a lado. El círculo con la «S» la rompía.
    for (var y = 178; y < 196; y++) {
      final verdes = [
        for (var x = 100; x < 120; x++) px.getUint8((y * ancho + x) * 4 + 1),
      ];
      final salto = verdes.reduce((a, b) => a > b ? a : b) -
          verdes.reduce((a, b) => a < b ? a : b);
      expect(salto, lessThan(24), reason: 'fila $y de la parrilla');
    }
  });

  test('el letrero sigue diciendo Barranquilla', () {
    // El texto gris claro del letrero de ruta, arriba.
    final letras =
        contar(50, 16, 168, 32, (r, g, b) => r > 120 && g > 120 && b > 120);
    expect(letras, greaterThan(60));
  });
}
