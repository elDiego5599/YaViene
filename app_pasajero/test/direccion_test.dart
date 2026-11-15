import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_pasajero/core/utils/direccion.dart';

void main() {
  group('direccionLegible: la forma «Cra 54 #72-80»', () {
    const casos = {
      // Los prefijos de la fuente, todos a «Cra» y «Clle».
      'CRA 12 # 63A - 04': 'Cra 12 #63A-04',
      'KR 30 N 23 35': 'Cra 30 #23-35',
      'KRA 30 N 23 35': 'Cra 30 #23-35',
      'CR 30 N 23 35': 'Cra 30 #23-35',
      'CARRERA 30 N 23 35': 'Cra 30 #23-35',
      'CLL 45 N 25 81': 'Clle 45 #25-81',
      'CL 45 N 25 81': 'Clle 45 #25-81',
      'CALLE 45 N 25 81': 'Clle 45 #25-81',
      'CLLE 45 N 25 81': 'Clle 45 #25-81',
      'CLL45 N 25 81': 'Clle 45 #25-81',
      // El «Sur» de los barrios del sur, pegado o separado.
      'CLL 49 N 12SUR 30': 'Clle 49 #12 Sur-30',
      'CLL 46 N 6C SUR 76': 'Clle 46 #6C Sur-76',
      'CRA 1C SUR N 5A 91': 'Cra 1C Sur #5A-91',
      // El separador del número: N, No., N°, # o nada.
      'CLL 47 No, 32 94': 'Clle 47 #32-94',
      'CLL 47 NO. 32 94': 'Clle 47 #32-94',
      'CLL 47 N° 32 94': 'Clle 47 #32-94',
      'CLL 44 36 12': 'Clle 44 #36-12',
      'CLL 84 N 67-54': 'Clle 84 #67-54',
      'CRA 1 N 91 - 04': 'Cra 1 #91-04',
      // Letras pegadas o sueltas, y las de dos caracteres.
      'CLL 76 N 15 A 20': 'Clle 76 #15A-20',
      'CLL 66 C N 7C 04': 'Clle 66C #7C-04',
      'CRA 3 E N 18H 16': 'Cra 3E #18H-16',
      'CRA 42B1 N 87-70': 'Cra 42B1 #87-70',
      'CLL 49K N 263 23': 'Clle 49K #263-23',
      'CRA 22SUR N 75 10 LOC 3': 'Cra 22 Sur #75-10, Loc 3',
      'cll 45 n 25 81': 'Clle 45 #25-81',
    };
    for (final MapEntry(key: fuente, value: esperada) in casos.entries) {
      test('$fuente → $esperada', () {
        expect(direccionLegible(fuente), esperada);
      });
    }
  });

  group('direccionLegible: lo que no encaja', () {
    test('cambia los prefijos y deja el resto legible', () {
      expect(
          direccionLegible('CLL 72 CRA 38 ESQUINA'), 'Clle 72 Cra 38 Esquina');
      expect(direccionLegible('CLL 63 PROLON. MURILLO'),
          'Clle 63 Prolon. Murillo');
    });
    test('las diagonales y transversales conservan su nombre', () {
      expect(direccionLegible('DIAG 77 N 14 05'), 'Diag 77 #14-05');
      expect(direccionLegible('DIG. 60 N 1C 04'), 'Diag 60 #1C-04');
      expect(direccionLegible('TRANV 6 # 55B - 105'), 'Trans 6 #55B-105');
      expect(direccionLegible('TV 15 C1 N 50 09'), 'Trans 15C1 #50-09');
    });
    test('vacía se queda vacía y sin prefijo no se inventa uno', () {
      expect(direccionLegible(''), '');
      expect(direccionLegible('  '), '');
      expect(direccionLegible('77D N 21 03'), '77D #21-03');
    });
  });
}
