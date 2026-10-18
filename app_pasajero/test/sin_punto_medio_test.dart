// El punto medio «·» no va en lo que el pasajero lee (dueño, 2026-10-18:
// «trata de no usar ese punto en ningún lado»). Separaba dos ideas en una
// fila; ahora las separa una coma o dos puntos, que además se leen en voz
// alta sin traducir. Se mira el código: cualquier texto nuevo que lo traiga
// cae aquí, no en una pantalla.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ningún texto de la app lleva «·»', () {
    final conPunto = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final lineas = f.readAsLinesSync();
      for (var i = 0; i < lineas.length; i++) {
        final codigo = lineas[i].split('//').first;
        if (codigo.contains('·')) conPunto.add('${f.path}:${i + 1}');
      }
    }
    expect(conPunto, isEmpty);
  });
}
