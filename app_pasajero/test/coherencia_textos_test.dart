import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// T6.5 · Los rótulos de la interfaz viven en dos sitios: aquí y en la
/// landing (`YaVieneWeb`), que los repite en los pasos de «Tres pasos»,
/// en el selector del mockup y en el simulador del teléfono. Nadie los
/// mira juntos: un día la app dice «Elige tu empresa» y la página sigue
/// con «Elige empresa» meses, porque ninguna prueba cruza los dos repos.
///
/// Los documentos legales ya se ataron así —`test/legal_*` aquí,
/// `tests/coherencia.test.ts` allá—, con la misma lista afirmada en los
/// dos lados. Esto hace lo mismo con la interfaz.
///
/// El listado espejo, con los archivos de la web, vive en
/// `YaVieneWeb/tests/coherencia-textos.test.ts`: si cambia una frase, se
/// cambia en los dos archivos de código y en las dos pruebas. Ninguna CI
/// trae el otro repo, así que cada lado se vigila solo y la lista
/// compartida es el eslabón.
void main() {
  /// frase → archivos de la app donde la frase tiene que estar.
  const frases = <String, List<String>>{
    '¿Qué bus esperas?': [
      'lib/features/map/presentation/widgets/search_pill_bar.dart',
    ],
    'Toca para buscar tu ruta': [
      'lib/features/map/presentation/widgets/search_pill_bar.dart',
    ],
    'Ruta activa': [
      'lib/features/map/presentation/widgets/search_pill_bar.dart',
    ],
    'Elige tu ruta': [
      'lib/features/map/presentation/widgets/route_selector_sheet.dart',
      'lib/features/map/presentation/providers/map_guide_copy.dart',
    ],
    'Elige empresa': [
      'lib/features/map/presentation/widgets/route_selector_sheet.dart',
    ],
    'Elegir empresa': [
      'lib/features/map/presentation/widgets/route_selector_sheet.dart',
    ],
    'Elige ruta': [
      'lib/features/map/presentation/widgets/route_selector_sheet.dart',
    ],
    'Cuál esperas': [
      'lib/features/map/presentation/widgets/route_selector_sheet.dart',
    ],
    'Con cuál viajas': [
      'lib/features/map/presentation/widgets/route_selector_sheet.dart',
    ],
    'Empresa de transporte masivo': [
      'lib/features/map/presentation/widgets/route_selector_sheet.dart',
    ],
    'Ver buses en vivo': [
      'lib/features/map/presentation/widgets/route_selector_sheet.dart',
    ],
    'Dos pasos y ves los buses moviéndose.': [
      'lib/features/map/presentation/widgets/route_selector_sheet.dart',
    ],
    'Avisarme cuando esté cerca': [
      'lib/features/map/presentation/widgets/eta_bottom_sheet.dart',
    ],
    'Aviso activado': [
      'lib/features/map/presentation/widgets/eta_bottom_sheet.dart',
    ],
    'Toca el mapa para indicar dónde estás': [
      'lib/features/map/presentation/widgets/eta_bottom_sheet.dart',
    ],
    'Puedes cambiar de aplicación; no cierres Ya Viene del todo': [
      'lib/features/map/presentation/widgets/eta_bottom_sheet.dart',
    ],
    'Localizando tu ubicación…': [
      'lib/features/map/presentation/widgets/location_status_chip.dart',
    ],
    'Arrástralo para moverlo': [
      'lib/features/map/presentation/widgets/location_status_chip.dart',
    ],
    'Fija tu punto de espera': [
      'lib/features/map/presentation/providers/map_guide_copy.dart',
    ],
    'Tu ciudad en tiempo real.': ['lib/core/widgets/ink_hero.dart'],
  };

  group('los rótulos de la interfaz siguen en su archivo', () {
    for (final entrada in frases.entries) {
      for (final archivo in entrada.value) {
        test('«${entrada.key}» sigue en $archivo', () {
          expect(
            File(archivo).readAsStringSync(),
            contains(entrada.key),
            reason:
                'La web repite esta frase (YaVieneWeb/tests/'
                'coherencia-textos.test.ts); si cambia aquí, cambia allá.',
          );
        });
      }
    }
  });
}
