import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Las pantallas de arranque nativas son blancas y vacías (dueño,
/// 2026-10-18): el arranque de Flutter (`EscenaArranque`) empieza en blanco
/// y arma la escena desde cero, así que cualquier cosa que la nativa pinte
/// —un color, la malla, el logo— saltaría en el relevo.
void main() {
  String leer(String ruta) => File(ruta).readAsStringSync();
  const res = 'android/app/src/main/res';

  test('iOS: el storyboard es blanco, sin imágenes', () {
    final s = leer('ios/Runner/Base.lproj/LaunchScreen.storyboard');
    expect(s, isNot(contains('<imageView')));
    expect(
      RegExp(r'<color key="backgroundColor" red="1" green="1" blue="1" '
              r'alpha="1"')
          .hasMatch(s),
      isTrue,
    );
  });

  test('Android: el color de arranque es blanco', () {
    expect(leer('$res/values/ic_launcher_background.xml'),
        contains('<color name="splash_background">#FFFFFF</color>'));
  });

  for (final d in ['drawable', 'drawable-v21']) {
    test('Android: $d/launch_background es solo el color', () {
      final s = leer('$res/$d/launch_background.xml');
      expect(s, contains('@color/splash_background'));
      expect(s, isNot(contains('<bitmap')));
      expect(s, isNot(contains('ic_splash_logo')));
    });
  }

  for (final v in ['values-v31', 'values-night-v31']) {
    test('Android 12+: $v deja blanco detrás del sistema', () {
      final s = leer('$res/$v/styles.xml');
      expect(
          s,
          contains('<item name="android:windowBackground">'
              '@color/splash_background</item>'));
    });
  }
}
