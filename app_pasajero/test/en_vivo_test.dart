import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// «En vivo», no «tiempo real» (dueño, 2026-10-27): ningún texto de la app
/// lo dice. Los comentarios no se leen en pantalla y no cuentan.
void main() {
  test('ningún texto de lib dice tiempo real', () {
    final hallados = <String>[];
    for (final archivo in Directory('lib').listSync(recursive: true)) {
      if (archivo is! File || !archivo.path.endsWith('.dart')) continue;
      final lineas = archivo.readAsLinesSync();
      for (var i = 0; i < lineas.length; i++) {
        final codigo = lineas[i].split('//').first;
        if (codigo.toLowerCase().contains('tiempo real')) {
          hallados.add('${archivo.path}:${i + 1}');
        }
      }
    }
    expect(hallados, isEmpty);
  });
}
