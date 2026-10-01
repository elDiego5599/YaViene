// T6.8 · Los estados del bus que lee el operador son los del glosario.
//
// `ya_viene_core/lib/core/texto/glosario.json` es el glosario único; la web
// pinta los mismos cuatro rótulos (`ROTULO` en `panel-flota.ts`, atado en
// `YaVieneWeb/tests/glosario.test.ts`). Si alguien escribe «Offline» o
// «Desconectado» en un solo sitio, esta prueba lo dice.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_control/features/fleet/presentation/bus_estado.dart';

void main() {
  test('cada estado del bus se rotula como dice el glosario', () {
    final glosario = jsonDecode(
      File('../ya_viene_core/lib/core/texto/glosario.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final estados = glosario['estadosBus'] as Map<String, dynamic>;
    expect(
      {for (final e in BusEstado.values) e.name: e.rotulo},
      {for (final k in estados.keys) k: estados[k]},
    );
  });
}
