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
    });

    test('el sí que se dio sobre el texto viejo no vale para este', () {
      // El documento cambió lo que promete, así que la bienvenida vuelve a
      // preguntar. Si alguien edita el texto y deja la versión quieta, esto
      // no lo caza; lo que caza es que la versión no se quede en la de antes
      // de esta tarea.
      // 3: la app cerrada del todo ya no sigue (29 de septiembre de 2026).
      // 4: el aviso de Android deja su punto en el servidor (2 de octubre).
      // 5: la distancia del aviso la elige la persona y viaja con el punto
      //    (6 de octubre).
      expect(kLegalVersion, greaterThanOrEqualTo(5));
      expect(legalPrivacidad.updated, '6 de octubre de 2026');
    });
  });

  // La distancia del aviso la elige la persona, de 500 m a 3 km (dueño,
  // 2026-10-06). El documento decía «un kilómetro a la redonda» y que con el
  // punto solo iban el bus, la ruta y el código de Firebase: las dos frases
  // dejaron de ser ciertas.
  group('la privacidad y la distancia del aviso', () {
    test('dice que el aviso suena a la distancia que elijas', () {
      final texto = textoDe(legalPrivacidad);
      expect(texto, contains('a la distancia que elijas'));
      expect(texto, contains('de 500 metros a 3 kilómetros'));
      expect(texto, isNot(contains('un kilómetro a la redonda')));
    });

    test('dice que esa distancia va al servidor con el punto', () {
      expect(
        textoDe(legalPrivacidad),
        contains('la distancia a la que pediste que te avise'),
      );
    });
  });

  // Los avisos con la app cerrada (D13 del backend): en Android el punto de
  // espera, redondeado, y el código de Firebase Cloud Messaging van al
  // servidor mientras hay un aviso armado. Hasta el 2 de octubre la política
  // decía que la ubicación no salía nunca del teléfono y que no había push;
  // las dos frases dejaron de ser ciertas y aquí se vigila que no vuelvan.
  group('la privacidad y los avisos con la app cerrada', () {
    test('dice qué sale, cuándo, redondeado y hasta cuándo', () {
      final texto = textoDe(legalPrivacidad);
      expect(texto, contains('La excepción es el aviso en Android'));
      expect(texto, contains('redondeado a unos 100 metros'));
      expect(texto, contains('como mucho a las tres horas de armarlo'));
      expect(texto, contains('En iPhone tu ubicación no sale del teléfono.'));
      expect(texto, isNot(contains('no usa ningún servicio de mensajería')));
      expect(texto, isNot(contains('Tu ubicación no sale del teléfono')));
    });

    test('nombra a Firebase Cloud Messaging entre los apoyos', () {
      final apoyos = legalPrivacidad.blocks
          .where((b) => b.kind == LegalBlockKind.bullet)
          .map((b) => b.text);
      expect(
        apoyos.where((t) => t.startsWith('Firebase Cloud Messaging')),
        hasLength(1),
      );
    });

    test('Google no recibe nada hasta que se arma un aviso', () {
      // La privacidad dice «solo para un aviso armado». Con el arranque
      // automático de FCM, el teléfono pediría su código a Google en cuanto
      // se abre la app, aviso o no.
      final manifiesto =
          File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
      expect(
        manifiesto,
        matches(RegExp(
          r'android:name="firebase_messaging_auto_init_enabled"\s*'
          r'android:value="false"',
        )),
      );
    });
  });
}
