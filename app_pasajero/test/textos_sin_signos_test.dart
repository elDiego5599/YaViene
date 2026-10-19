import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Lo que lee el pasajero va sin comillas angulares ni rayas (dueño,
/// 2026-10-18: «no uses caracteres especiales como << o -- en los textos»).
/// Se escribe con comas, dos puntos, paréntesis y «a» entre dos cifras.
/// Fuera quedan los comentarios y los dos mensajes que solo ve quien
/// programa: el `StateError` de `config.dart` y un `ArgumentError`.
void main() {
  final prohibidos = RegExp(r'[«»—–]|--');
  final soloProgramador = RegExp(r'--dart-define|ArgumentError');

  test('los textos de la app no llevan «», rayas ni --', () {
    final hallados = <String>[];
    final fuentes = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));
    for (final f in fuentes) {
      final lineas = f.readAsLinesSync();
      for (var i = 0; i < lineas.length; i++) {
        final l = lineas[i];
        final codigo = l.split('//').first;
        if (!codigo.contains("'") && !codigo.contains('"')) continue;
        if (soloProgramador.hasMatch(codigo)) continue;
        if (prohibidos.hasMatch(codigo)) hallados.add('${f.path}:${i + 1}');
      }
    }
    expect(hallados, isEmpty);
  });
}
