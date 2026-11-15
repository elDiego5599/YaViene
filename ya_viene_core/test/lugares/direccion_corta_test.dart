import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_core/core/lugares/direccion_corta.dart';

/// Así se escriben las direcciones en Barranquilla (dueño, 2026-11-15):
/// «Cra 54 #72-80», «Clle 72 #54-20». Venga como venga, se dice así.
void main() {
  test('la carrera y sus formas son Cra', () {
    for (final escrita in [
      'Carrera 54 # 72-80',
      'Cra 54 #72-80',
      'Cra. 54 # 72 - 80',
      'Kr 54 N° 72-80',
      'KR 54 No. 72-80',
      'Kra 54 Nro 72-80',
      'Cr 54 # 72-80',
      'K 54 # 72-80',
      'carrera 54 #72-80',
      'Carrera54#72-80',
    ]) {
      expect(direccionCorta(escrita), 'Cra 54 #72-80', reason: escrita);
    }
  });

  test('la calle y sus formas son Clle', () {
    for (final escrita in [
      'Calle 72 # 54-20',
      'Cl. 72 No. 54-20',
      'Cl 72 # 54 - 20',
      'Cll 72 #54-20',
      'Clle 72 #54-20',
      'C 72 N° 54-20',
      'CALLE 72 Nº 54-20',
      'Calle 72 Número 54-20',
    ]) {
      expect(direccionCorta(escrita), 'Clle 72 #54-20', reason: escrita);
    }
  });

  test('la diagonal es Dg y la transversal es Tv', () {
    expect(direccionCorta('Diagonal 70 # 12-5'), 'Dg 70 #12-5');
    expect(direccionCorta('Diag. 70 No. 12-5'), 'Dg 70 #12-5');
    expect(direccionCorta('Transversal 38 # 4-10'), 'Tv 38 #4-10');
    expect(direccionCorta('Transv 38 N° 4-10'), 'Tv 38 #4-10');
    expect(direccionCorta('Tr 38 # 4-10'), 'Tv 38 #4-10');
  });

  test('la letra y el bis van pegados al número, la letra en mayúscula', () {
    expect(direccionCorta('Carrera 46b # 72-20'), 'Cra 46B #72-20');
    expect(direccionCorta('Calle 72 B # 46 C - 20'), 'Clle 72B #46C-20');
    expect(direccionCorta('Carrera 46 Bis # 72-20'), 'Cra 46Bis #72-20');
  });

  test('las esquinas y las vías solas también', () {
    expect(direccionCorta('Calle 72 con Carrera 46'), 'Clle 72 con Cra 46');
    expect(direccionCorta('Carrera 46 con 72'), 'Cra 46 con 72');
    expect(direccionCorta('Calle 72'), 'Clle 72');
    expect(direccionCorta('Calle 72 #46'), 'Clle 72 #46');
  });

  test('lo que no es nomenclatura se queda como vino', () {
    for (final nombre in [
      'Avenida Circunvalar',
      'Vía 40',
      'El Prado',
      'Centro Comercial Buenavista',
      'Universidad del Norte',
      'Vitamina C',
      'La Calle Real',
      'Calle Murillo',
      'No hay 2 sin 3',
    ]) {
      expect(direccionCorta(nombre), nombre, reason: nombre);
    }
  });
}
