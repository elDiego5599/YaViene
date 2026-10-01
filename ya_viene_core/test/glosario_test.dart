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
    'a504203047349505e763090f95f60db4bf595c9f9183dd5ca55463427bfe0b74';

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
    final aviso = g['aviso'] as Map;
    // Regla 12: distintos a propósito. Si un día coinciden, alguien
    // unificó lo que no se unifica.
    expect(aviso['landing'], isNot(aviso['app']));
    expect(aviso['landing'], isNot(contains('{placa}')));
    expect(aviso['app'], contains('{placa}'));
  });
}
