import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

/// T6.8 · El glosario es uno, en dos copias.
///
/// `lib/core/texto/glosario.json` y `YaVieneWeb/src/glosario.json` son el
/// mismo archivo. Ninguna CI trae el otro repo, así que el eslabón es este
/// hash, escrito igual en `YaVieneWeb/tests/glosario.test.ts`: quien cambie
/// una copia cambia el hash en su prueba, y el mismo cambio queda por hacer
/// en la otra. Con los dos repos uno junto al otro, además, se comparan
/// byte a byte.
///
/// Que cada palabra sea la que se pinta lo vigilan
/// `app_control/test/glosario_test.dart` y
/// `app_pasajero/test/glosario_test.dart`.
const kHashGlosario =
    '65ac0343916432e7685db56de8d9017ffeef5559a4974c68ab18498d7d55a221';

const _ruta = 'lib/core/texto/glosario.json';

void main() {
  test('el glosario es el del hash compartido con la web', () {
    final bytes = File(_ruta).readAsBytesSync();
    expect(sha256.convert(bytes).toString(), kHashGlosario);
  });

  test('con la web al lado, las dos copias son idénticas', () {
    final web = File('../../YaVieneWeb/src/glosario.json');
    if (!web.existsSync()) {
      markTestSkipped('sin YaVieneWeb junto a YaViene (la CI de un repo)');
      return;
    }
    expect(web.readAsStringSync(), File(_ruta).readAsStringSync());
  });

  test('trae estados, términos, distancia y los dos avisos', () {
    final g = jsonDecode(File(_ruta).readAsStringSync()) as Map;
    expect((g['estadosBus'] as Map).keys,
        containsAll(['enLinea', 'inactivo', 'sinSenal', 'oculto']));
    expect((g['terminos'] as Map).keys,
        containsAll(['placa', 'ruta', 'interno', 'sentido']));
    expect((g['distancia'] as Map).keys,
        containsAll(['metros', 'kilometros', 'separadorDecimal']));
    final aviso = (g['aviso'] as Map)['texto'] as String;
    // Un solo aviso, el mismo en la landing y en la app (dueño, 2026-10-30:
    // «Tu bus de la ruta X» se leía largo junto a la actividad en vivo,
    // que ya decía lo corto). Sin ruta, placa ni distancia: la ficha de la
    // ruta va en la imagen del aviso.
    expect(aviso, 'Tu bus está cerca de ti');
    expect(aviso, isNot(contains('{')));
  });
}
