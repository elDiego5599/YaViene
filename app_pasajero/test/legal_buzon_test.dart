import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_pasajero/features/legal/legal_docs.dart';

/// El buzón (D14) manda al servidor lo que el pasajero escribe, y el servidor
/// lo reenvía al Gmail del equipo. La privacidad decía que, salvo el aviso de
/// Android, nada salía del teléfono, y no nombraba ni el buzón ni Gmail
/// (AUD16-01). Las frases se atan a lo que `buzon.dart` manda de verdad.
///
/// La misma copia está en `YaVieneWeb/privacidad.html`; allí la vigila
/// `tests/coherencia.test.ts`.
void main() {
  String textoDe(LegalDoc doc) => doc.blocks.map((b) => b.text).join(' ');

  test('la privacidad cuenta qué viaja con el buzón y a dónde', () {
    final texto = textoDe(legalPrivacidad);
    expect(texto, contains('Si nos escribes por el buzón'));
    expect(
      texto,
      contains(
        'viaja a nuestro servidor con el tipo que elegiste, si tu teléfono '
        'es Android o iPhone y la versión de la app',
      ),
    );
    expect(texto, contains('al correo del equipo, en Gmail, y lo borra'));
    expect(texto, contains('Gmail, de Google'));
  });

  test('la privacidad cuenta qué lleva una queja y quién la lee (D18)', () {
    final texto = textoDe(legalPrivacidad);
    expect(texto, contains('un problema, una sugerencia o una queja'));
    expect(
      texto,
      contains(
        'Una queja sobre un bus o su conductor lleva además el motivo que '
        'elegiste y, si los pones, la ruta, el bus y la hora en punto',
      ),
    );
    expect(texto, contains('Tu ubicación solo va si enciendes el interruptor'));
    expect(texto, contains('nunca tu punto exacto'));
    expect(
      texto,
      contains('se guarda 13 meses para que la empresa dueña de esa ruta'),
    );
    // Lo de antes ya no es verdad para la queja con zona.
    expect(texto, isNot(contains('y tu ubicación no va.')));
    expect(texto, isNot(contains('Lleva tu mensaje, no tu ubicación.')));
  });

  test('lo que la privacidad dice que viaja es lo que manda la app', () {
    final buzon = File('lib/features/buzon/data/buzon.dart').readAsStringSync();
    final campos =
        RegExp(r"'(\w+)':").allMatches(buzon).map((m) => m.group(1)).toSet();
    expect(
      campos,
      {
        'tipo', 'texto', 'plataforma', 'version',
        // La queja (D18): la celda va con su `lat` y su `lng`.
        'motivo', 'routeId', 'busId', 'hora', 'celda', 'lat', 'lng',
      },
      reason: 'si la app manda otro campo, la privacidad tiene que decirlo',
    );
    expect(buzon, contains('centroCeldaBusqueda'));
  });

  test('el texto nuevo vuelve a pedir el sí, con su fecha', () {
    // 6: el buzón manda lo que escribes al correo del equipo (18 de octubre).
    // 8: la queja puede llevar la zona y la lee la empresa (11 de noviembre).
    expect(kLegalVersion, greaterThanOrEqualTo(8));
    expect(legalPrivacidad.updated, '11 de noviembre de 2026');
  });
}
