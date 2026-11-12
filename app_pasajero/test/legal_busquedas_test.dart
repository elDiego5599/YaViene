import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_pasajero/features/legal/legal_docs.dart';

/// Las búsquedas de ruta (D17 del backend): al elegir empresa y ruta, la app
/// manda la ruta y, si conoce tu punto, el centro de una casilla de unos
/// 150 m (`busquedas_api.dart`). La privacidad decía que en iPhone la
/// ubicación no salía nunca del teléfono, y en los dos sistemas sale así.
/// Los contadores solo los consulta la empresa dueña de la ruta (dueño,
/// 2026-10-27: un trato en el que ganan los dos).
///
/// La misma copia está en `YaVieneWeb/privacidad.html`; allí la vigila
/// `tests/coherencia.test.ts`.
void main() {
  String textoDe(LegalDoc doc) => doc.blocks.map((b) => b.text).join(' ');

  test('la privacidad cuenta qué sale al buscar una ruta y quién lo ve', () {
    final texto = textoDe(legalPrivacidad);
    expect(texto, contains('Las búsquedas de ruta, para las empresas'));
    expect(texto, contains('una casilla de unos 150 metros de lado'));
    expect(texto, contains('ni tu teléfono, ni tu dirección IP'));
    expect(texto, contains('Solo la empresa dueña de cada ruta'));
    expect(texto, contains('al menos cinco búsquedas'));
    expect(texto, contains('se borran a los 13 meses'));
    expect(texto, contains('ganan los dos'));
  });

  test('ya no promete que en iPhone la ubicación no sale', () {
    final texto = textoDe(legalPrivacidad);
    expect(texto, isNot(contains('En iPhone tu ubicación no sale')));
    expect(texto, isNot(contains('solo sale del teléfono para el aviso')));
  });

  test('en iPhone el aviso sigue con la pantalla bloqueada', () {
    // `mantener_vivo.dart` mantiene la ubicación en segundo plano mientras
    // hay un aviso armado; cerrada del todo, la app no se pone al día.
    final texto = textoDe(legalPrivacidad);
    expect(texto, isNot(contains('En iPhone el aviso solo suena con la app')));
    expect(texto, contains('con la pantalla bloqueada'));
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    expect(plist, contains('<string>location</string>'));
  });

  test('lo que la privacidad dice que viaja es lo que manda la app', () {
    final api =
        File('lib/features/map/data/busquedas_api.dart').readAsStringSync();
    final campos =
        RegExp(r"'(\w+)':").allMatches(api).map((m) => m.group(1)).toSet();
    expect(
      campos,
      {'routeId', 'celda', 'lat', 'lng'},
      reason: 'si la app manda otro campo, la privacidad tiene que decirlo',
    );
    expect(api, contains('centroCeldaBusqueda'));
  });

  test('el texto nuevo vuelve a pedir el sí', () {
    // 7: las búsquedas de ruta salen del teléfono (27 de octubre). La fecha
    // la lleva ahora `legal_buzon_test.dart` (8, 11 de noviembre).
    expect(kLegalVersion, greaterThanOrEqualTo(7));
  });
}
