import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ya_viene_pasajero/core/app_info.dart';
import 'package:ya_viene_pasajero/features/legal/legal_acceptance.dart';
import 'package:ya_viene_pasajero/features/legal/legal_docs.dart';
import 'package:ya_viene_pasajero/features/onboarding/onboarding_flow.dart';

/// La puerta de entrada: privacidad y términos se aceptan antes del mapa.
///
/// Sin cuenta no hay un servidor que recuerde quién aceptó qué, así que la
/// aceptación vive en el teléfono y lleva número de versión: el día que los
/// documentos cambien, la app vuelve a preguntar en lugar de dar por bueno
/// un sí que se dio sobre otro texto.
void main() {
  group('la ruta de arranque', () {
    test('un teléfono recién instalado empieza en la bienvenida', () async {
      SharedPreferences.setMockInitialValues({});
      expect(await rutaDeArranque(), '/onboarding');
    });

    test('haber visto la bienvenida ya no basta para pasar', () async {
      // Quien instaló la app antes de esta pantalla tiene la marca de
      // "vista" y no ha aceptado nada: vuelve a la bienvenida una vez.
      SharedPreferences.setMockInitialValues({'onboarding_seen': true});
      expect(await rutaDeArranque(), '/onboarding');
    });

    test('vista y aceptada, la app abre en el mapa', () async {
      SharedPreferences.setMockInitialValues({
        'onboarding_seen': true,
        'legal_accepted_version': kLegalVersion,
      });
      expect(await rutaDeArranque(), '/map');
    });

    test('una versión nueva de los documentos vuelve a preguntar', () async {
      SharedPreferences.setMockInitialValues({
        'onboarding_seen': true,
        'legal_accepted_version': kLegalVersion - 1,
      });
      expect(await rutaDeArranque(), '/onboarding');
    });
  });

  group('la aceptación', () {
    test('se guarda con la versión de los documentos que se aceptó',
        () async {
      SharedPreferences.setMockInitialValues({});
      expect(await isLegalAccepted(), isFalse);

      await acceptLegal();

      expect(await isLegalAccepted(), isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('legal_accepted_version'), kLegalVersion);
    });
  });

  group('los documentos', () {
    test('son los dos que la app enseña y nombra por su camino', () {
      expect(legalDocById('privacidad'), same(legalPrivacidad));
      expect(legalDocById('terminos'), same(legalTerminos));
      expect(legalDocById('cualquier-cosa'), isNull);
    });

    test('ninguno llega vacío ni con un bloque en blanco', () {
      for (final doc in legalDocs) {
        expect(doc.title, isNotEmpty);
        expect(doc.updated, isNotEmpty);
        expect(doc.blocks, isNotEmpty);
        for (final bloque in doc.blocks) {
          expect(bloque.text.trim(), isNotEmpty, reason: doc.id);
        }
        // Un documento legal sin encabezados es un muro de texto.
        expect(
          doc.blocks.any((b) => b.kind == LegalBlockKind.heading),
          isTrue,
          reason: doc.id,
        );
      }
    });

    test('los dos dejan el mismo canal de contacto que la página', () {
      for (final doc in legalDocs) {
        final entero = doc.blocks.map((b) => b.text).join(' ');
        expect(entero, contains('300 443 8626'), reason: doc.id);
      }
    });
  });

  test('la versión que dice "Acerca de" es la que se compila', () {
    // Sin `package_info_plus`: un plugin entero para una cadena que ya está
    // escrita en el pubspec. La constante se escribe a mano y esta prueba
    // es la que no deja que se quede vieja.
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final linea = RegExp(r'^version:\s*(\S+)\s*$', multiLine: true)
        .firstMatch(pubspec);
    expect(linea, isNotNull, reason: 'el pubspec tiene que declarar version');
    expect(linea!.group(1), '$kAppVersion+$kAppBuild');
  });
}
