import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_control/main.dart' show manejaVentana;

/// Quién arma la ventana del panel. En macOS y Windows la abre
/// `window_manager` (tamaño mínimo, maximizada); en el navegador la ventana
/// es la pestaña y ese plugin no existe. `dart:io` tampoco: su `Platform`
/// lanza en web, y un navegador en un Mac dice macOS en
/// `defaultTargetPlatform`, así que lo que manda es [kIsWeb].
void main() {
  test('en escritorio el panel arma su ventana', () {
    for (final p in [
      TargetPlatform.macOS,
      TargetPlatform.windows,
      TargetPlatform.linux,
    ]) {
      expect(manejaVentana(web: false, plataforma: p), isTrue, reason: '$p');
    }
  });

  test('en el navegador no, aunque corra en un Mac o en Windows', () {
    for (final p in TargetPlatform.values) {
      expect(manejaVentana(web: true, plataforma: p), isFalse, reason: '$p');
    }
  });

  test('en un teléfono tampoco', () {
    expect(manejaVentana(web: false, plataforma: TargetPlatform.iOS), isFalse);
    expect(
      manejaVentana(web: false, plataforma: TargetPlatform.android),
      isFalse,
    );
  });
}
