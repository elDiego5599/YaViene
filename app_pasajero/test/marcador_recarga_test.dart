import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

import 'package:ya_viene_pasajero/features/recarga/marcador_recarga.dart';

double _luminancia(ui.Color c) {
  double f(double v) =>
      v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * f(c.r) + 0.7152 * f(c.g) + 0.0722 * f(c.b);
}

double _contraste(ui.Color a, ui.Color b) {
  final la = _luminancia(a), lb = _luminancia(b);
  return (max(la, lb) + 0.05) / (min(la, lb) + 0.05);
}

void main() {
  test('el morado de recarga pasa 7:1 con el blanco y con el papel del mapa',
      () {
    expect(
        _contraste(moradoRecarga, const ui.Color(0xFFFFFFFF)), greaterThan(7));
    expect(
        _contraste(moradoRecarga, const ui.Color(0xFFF4F2EE)), greaterThan(7));
  });

  test('el tono del morado queda a 30 grados o más del azul y del rojo', () {
    final tono = HSLColor.fromColor(moradoRecarga).hue;
    for (final otro in [AppColors.acento, AppColors.busActive]) {
      final d = (tono - HSLColor.fromColor(otro).hue).abs();
      expect(min(d, 360 - d), greaterThan(30));
    }
  });

  testWidgets('pintarMarcadorRecarga da un PNG de 36 pt a 3x', (t) async {
    final bytes = await t.runAsync(pintarMarcadorRecarga);
    expect(bytes!.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
    final codec = await t.runAsync(() => ui.instantiateImageCodec(bytes));
    final frame = await t.runAsync(codec!.getNextFrame);
    expect(frame!.image.width, ladoMarcadorRecarga * escalaMarcadorRecarga);
  });
}
