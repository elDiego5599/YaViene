import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Configuración común de las pruebas de oro.
///
/// Vive en `test/golden/` a propósito: `flutter test` busca este archivo
/// desde la carpeta de cada prueba hacia arriba y usa el primero que
/// encuentra, así que cargar fuentes aquí no cambia el renderizado de las
/// pruebas de comportamiento que viven en `test/` —varias miden alturas y
/// se romperían si de pronto el texto midiera otra cosa.
///
/// Sin esto el motor pinta con Ahem, la tipografía de cajas: una foto de
/// referencia sin tipografía real no diría nada de la tipografía, que es
/// justo lo que estas pruebas vigilan. También entra MaterialIcons, así
/// que los iconos salen dibujados y no como cuadros vacíos.
///
/// Se lee el FontManifest que `flutter test` deja en el bundle, no una
/// lista escrita a mano: una fuente nueva en el `pubspec.yaml` entra sola.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await _cargarFuentes();
  return testMain();
}

Future<void> _cargarFuentes() async {
  final manifiesto = json.decode(
    await rootBundle.loadString('FontManifest.json'),
  ) as List<dynamic>;

  for (final entrada in manifiesto.cast<Map<String, dynamic>>()) {
    final cargador = FontLoader(entrada['family'] as String);
    final fuentes = (entrada['fonts'] as List).cast<Map<String, dynamic>>();
    for (final fuente in fuentes) {
      cargador.addFont(rootBundle.load(fuente['asset'] as String));
    }
    await cargador.load();
  }
}
