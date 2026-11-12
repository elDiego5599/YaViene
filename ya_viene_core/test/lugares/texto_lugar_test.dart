import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_core/core/lugares/texto_lugar.dart';

void main() {
  group('palabrasDe', () {
    test('quita tildes, mayúsculas y signos', () {
      expect(palabrasDe('Barrio ABAJO'), ['barrio', 'abajo']);
      expect(palabrasDe('Santa Mónica'), ['santa', 'monica']);
      expect(palabrasDe('La Campiña'), ['la', 'campina']);
      expect(palabrasDe('  Pradomar,   Puerto  '), ['pradomar', 'puerto']);
    });

    test('lleva las abreviaturas de la nomenclatura a su nombre', () {
      expect(palabrasDe('Cra 46'), ['carrera', '46']);
      expect(palabrasDe('Kr 46'), ['carrera', '46']);
      expect(palabrasDe('Cr. 46'), ['carrera', '46']);
      expect(palabrasDe('Cl 72'), ['calle', '72']);
      expect(palabrasDe('Cll 72'), ['calle', '72']);
      expect(palabrasDe('Av. Circunvalar'), ['avenida', 'circunvalar']);
      expect(palabrasDe('Dg 70'), ['diagonal', '70']);
      expect(palabrasDe('Tv 38'), ['transversal', '38']);
    });

    test('la c y la k solas solo son calle y carrera delante de un número', () {
      expect(palabrasDe('C 72'), ['calle', '72']);
      expect(palabrasDe('K 46'), ['carrera', '46']);
      expect(palabrasDe('Vitamina C'), ['vitamina', 'c']);
    });

    test('el numeral y sus formas son el mismo separador', () {
      expect(palabrasDe('Calle 72 # 46-20'), ['calle', '72', '#', '46', '20']);
      expect(
          palabrasDe('Calle 72 No. 46-20'), ['calle', '72', '#', '46', '20']);
      expect(palabrasDe('Calle 72 N° 46'), ['calle', '72', '#', '46']);
      expect(palabrasDe('Calle 72#46'), ['calle', '72', '#', '46']);
    });

    test('pega la letra y el bis al número de la vía', () {
      expect(palabrasDe('Calle 72B'), ['calle', '72b']);
      expect(palabrasDe('Calle 72 B'), ['calle', '72b']);
      expect(palabrasDe('Carrera 46 bis'), ['carrera', '46bis']);
      expect(palabrasDe('Calle 72 c 46'), ['calle', '72', 'calle', '46']);
    });

    test('separa la vía pegada a su número, como se escribe a la carrera', () {
      expect(palabrasDe('Cl72'), ['calle', '72']);
      expect(palabrasDe('kr46#72-20'), ['carrera', '46', '#', '72', '20']);
      expect(palabrasDe('Cra46B'), ['carrera', '46b']);
      expect(palabrasDe('Calle72'), ['calle', '72']);
      expect(palabrasDe('No46'), ['#', '46']);
      // Lo que no es nomenclatura se queda como vino.
      expect(palabrasDe('R111'), ['r111']);
    });
  });

  group('casiIgual', () {
    test('perdona una letra de más, de menos, cambiada o volteada', () {
      expect(casiIgual('prado', 'prado'), isTrue);
      expect(casiIgual('pradoo', 'prado'), isTrue);
      expect(casiIgual('prdo', 'prado'), isTrue);
      expect(casiIgual('prafo', 'prado'), isTrue);
      expect(casiIgual('pardo', 'prado'), isTrue);
    });

    test('no perdona dos', () {
      expect(casiIgual('pardoo', 'prado'), isFalse);
      expect(casiIgual('boyaca', 'bolivar'), isFalse);
    });

    test('en palabras cortas exige la palabra exacta', () {
      expect(casiIgual('sol', 'col'), isFalse);
      expect(casiIgual('72', '73'), isFalse);
    });
  });
}
