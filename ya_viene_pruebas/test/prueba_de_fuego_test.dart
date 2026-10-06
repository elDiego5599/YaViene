import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// La lista de `tool/prueba_de_fuego.dart` se pudre en silencio si alguien
/// cambia una línea que muta: la mutación deja de aplicar y nadie se entera.
/// Aquí cada una tiene que estar exactamente una vez en su archivo y cambiar
/// algo de verdad.
void main() {
  final lista =
      (jsonDecode(File('../tool/prueba-de-fuego.json').readAsStringSync())
              as List)
          .cast<Map<String, dynamic>>();

  test('la prueba de fuego cubre las piezas que importan', () {
    expect(lista.length, greaterThanOrEqualTo(75));
    final paquetes =
        lista.map((m) => (m['archivo'] as String).split('/').first);
    expect(paquetes.toSet(),
        containsAll(['ya_viene_core', 'app_pasajero', 'app_control']));
  });

  test('cada mutación aplica una sola vez y cambia algo', () {
    for (final (i, m) in lista.indexed) {
      final archivo = m['archivo'] as String;
      final de = m['de'] as String;
      final fuente = File('../$archivo').readAsStringSync();
      expect(fuente.split(de).length, 2,
          reason: '#${i + 1}: «$de» tiene que estar una vez en $archivo');
      expect(m['a'], isNot(de), reason: '#${i + 1} no cambia nada');
      expect(m['que'], isA<String>());
    }
  });
}
