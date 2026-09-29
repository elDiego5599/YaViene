import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_pasajero/features/legal/legal_docs.dart';

/// Lo que el documento de privacidad promete sobre el segundo plano, atado a
/// lo que el manifiesto permite de verdad (T5.5, paso 3).
///
/// La app arranca un servicio en primer plano en Android para que el socket
/// no muera al salir de ella, y eso le pone al usuario una notificación fija
/// delante. Lo que el servicio **no** hace es seguir leyendo el GPS: la app
/// pide «solo mientras la uso» y no declara `ACCESS_BACKGROUND_LOCATION`, así
/// que mientras no esté delante la distancia se mide contra el último punto
/// conocido o contra el punto de espera marcado a mano.
///
/// Las dos mitades de esa frase pueden separarse sin que nadie se entere: se
/// añade el permiso para arreglar otra cosa y el documento se queda diciendo
/// que no está, que es la peor manera de mentir en un texto que el usuario
/// acepta. Por eso la prueba lee el manifiesto y no solo la copia.
///
/// La misma copia está en `YaVieneWeb/privacidad.html`; allí la vigila
/// `tests/coherencia.test.ts`.
void main() {
  String textoDe(LegalDoc doc) => doc.blocks.map((b) => b.text).join(' ');

  group('la privacidad y el segundo plano', () {
    test('el documento dice qué pasa cuando sales de la app', () {
      final texto = textoDe(legalPrivacidad);
      expect(texto, contains('solo mientras la uso'));
      expect(texto, contains('no el de segundo plano'));
      expect(
        texto,
        contains('la distancia se mide contra el último punto que conoció'),
      );
    });

    test('dice también que en Android se ve una notificación fija', () {
      // Es lo que el usuario nota, y no decirlo hace que parezca que la app
      // se quedó encendida por su cuenta.
      expect(textoDe(legalPrivacidad), contains('notificación fija'));
    });

    test('el manifiesto no pide ubicación en segundo plano', () {
      final manifiesto =
          File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
      expect(
        manifiesto.contains('ACCESS_BACKGROUND_LOCATION'),
        isFalse,
        reason: 'si se añade el permiso, la privacidad deja de ser cierta',
      );
      // El tipo de servicio también importa: con `location` el sistema sí
      // dejaría seguir leyendo el GPS, y el documento volvería a mentir.
      expect(manifiesto, contains('android:foregroundServiceType="dataSync"'));
    });

    test('dice que cerrar la app del todo detiene el seguimiento', () {
      // Desde la auditoría 2026-09 (H1) el servicio solo vive con un aviso
      // armado y muere con la tarea (`stopWithTask="true"`): el texto que
      // prometía seguimiento con la app cerrada dejó de ser cierto.
      final texto = textoDe(legalPrivacidad);
      expect(texto, contains('sin cerrarla y tienes un aviso activo'));
      expect(
        texto,
        contains('Si cierras la app del todo, el seguimiento se detiene'),
      );
      expect(texto, isNot(contains('aunque cierres la app')));
      final manifiesto =
          File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
      expect(manifiesto, contains('android:stopWithTask="true"'));
      expect(legalPrivacidad.updated, '29 de septiembre de 2026');
    });

    test('el sí que se dio sobre el texto viejo no vale para este', () {
      // El documento cambió lo que promete, así que la bienvenida vuelve a
      // preguntar. Si alguien edita el texto y deja la versión quieta, esto
      // no lo caza; lo que caza es que la versión no se quede en la de antes
      // de esta tarea.
      // 3: la app cerrada del todo ya no sigue (29 de septiembre de 2026).
      expect(kLegalVersion, greaterThanOrEqualTo(3));
    });
  });
}
