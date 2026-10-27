import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_pasajero/features/legal/legal_docs.dart';

/// Ninguna cifra se promete exacta (dueño, 2026-10-27): el GPS tarda y se
/// desvía, y prometer exactitud es lo que vuelve reclamable una cifra que
/// falla. La misma frase está en `YaVieneWeb/terminos.html`, que vigila
/// `tests/coherencia.test.ts`.
void main() {
  test('los términos dicen que distancias y cifras son aproximadas', () {
    final texto = legalTerminos.blocks.map((b) => b.text).join(' ');
    expect(
      texto,
      contains(
        'Las distancias y las demás cifras que muestra la app son '
        'aproximadas.',
      ),
    );
    expect(legalTerminos.updated, '27 de octubre de 2026');
  });
}
