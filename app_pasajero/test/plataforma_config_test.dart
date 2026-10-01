import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Candado de la configuración nativa del pasajero (T3.14).
///
/// Estas líneas no las toca ningún código Dart, así que ninguna otra prueba
/// se enteraría si alguien las afloja: un `NSAllowsArbitraryLoads` pegado
/// desde un tutorial, un `debuggable` para depurar una noche o el texto
/// plano hacia el emulador colado en la APK que va a los teléfonos. Se leen
/// los archivos tal como están en el repositorio y se falla si alguna
/// regresa. `flutter test` corre con el paquete como directorio de trabajo,
/// de ahí las rutas relativas.
void main() {
  group('iOS', () {
    test('Info.plist no abre ATS: nada de NSAllowsArbitraryLoads', () {
      // El backend real siempre es HTTPS (el túnel de ngrok, Fly de
      // respaldo). Con ATS abierto, una URL http mal escrita saldría en
      // claro en vez de fallar a la vista. Se prohíbe también cualquier
      // variante (…InWebContent, …ForMedia): no hay web ni video que la pida.
      final plist = _leer('ios/Runner/Info.plist');
      expect(plist, isNot(contains('NSAllowsArbitraryLoads')));
    });
  });

  group('Android', () {
    const main = 'android/app/src/main';
    const gradle = 'android/app/build.gradle.kts';

    test('ningún manifiesto se declara debuggable', () {
      // `debug` ya es depurable por su tipo de compilación; escribirlo en un
      // manifiesto lo volvería depurable también en release (cualquiera con
      // un cable leería la memoria y las preferencias de la app).
      for (final ruta in _manifiestos()) {
        expect(
          _sinComentariosXml(_leer(ruta)),
          isNot(contains('android:debuggable')),
          reason: ruta,
        );
      }
    });

    test('el release no se marca depurable en build.gradle.kts', () {
      final release = _bloqueRelease(_sinComentariosKts(_leer(gradle)));
      expect(release, isNot(matches(RegExp(r'isDebuggable\s*=\s*true'))));
      expect(release, isNot(matches(RegExp(r'isJniDebuggable\s*=\s*true'))));
    });

    test('el servicio de fondo se para con la tarea y el merger lo acepta', () {
      // El plugin declara el mismo servicio con stopWithTask="false": sin
      // nombrarlo en tools:replace, el merger de manifiestos tumba la APK.
      // Linux sin SDK de Android no lo ve; esta prueba sí.
      final servicio = RegExp(
        r'<service[^>]*BackgroundService[^>]*>',
      )
          .firstMatch(_sinComentariosXml(_leer('$main/AndroidManifest.xml')))!
          .group(0)!;
      expect(servicio, contains('android:stopWithTask="true"'));
      final reemplaza =
          RegExp(r'tools:replace="([^"]*)"').firstMatch(servicio)!.group(1)!;
      expect(reemplaza.split(','), contains('android:stopWithTask'));
    });

    test('R8 (minify y recorte de recursos) activo en release', () {
      // El plugin de Flutter ya lo prende por defecto, pero en silencio y
      // apagable con `-Pshrink=false`; escrito aquí queda a la vista y esta
      // prueba lo sostiene.
      final release = _bloqueRelease(_sinComentariosKts(_leer(gradle)));
      expect(release, matches(RegExp(r'isMinifyEnabled\s*=\s*true')));
      expect(release, matches(RegExp(r'isShrinkResources\s*=\s*true')));
      final props = _leer('android/gradle.properties');
      expect(
        props,
        isNot(matches(RegExp(r'^\s*shrink\s*=\s*false', multiLine: true))),
      );
    });

    test('el manifiesto principal aplica la política de red', () {
      expect(
        _sinComentariosXml(_leer('$main/AndroidManifest.xml')),
        contains(
            'android:networkSecurityConfig="@xml/network_security_config"'),
      );
      expect(
        _sinComentariosXml(_leer('$main/AndroidManifest.xml')),
        isNot(contains('usesCleartextTraffic="true"')),
      );
    });

    test('la política principal (release y profile) no deja texto plano', () {
      // Lo que va a los teléfonos habla solo HTTPS: sin excepciones, ni
      // siquiera localhost o 10.0.2.2, que en un teléfono de verdad no son
      // el backend sino cualquier cosa que escuche en ese puerto.
      final xml = _sinComentariosXml(
        _leer('$main/res/xml/network_security_config.xml'),
      );
      expect(xml, contains('<base-config cleartextTrafficPermitted="false"'));
      expect(xml, isNot(contains('cleartextTrafficPermitted="true"')));
      expect(xml, isNot(contains('<domain-config')));
      // Tampoco se confía en certificados que instale el usuario.
      expect(xml, isNot(contains('src="user"')));
    });

    test('la excepción de desarrollo vive solo en src/debug', () {
      // Gradle sobrepone los recursos de src/debug a los de src/main solo en
      // la variante debug: ahí, y solo ahí, se permite HTTP hacia el backend
      // local (localhost y 10.0.2.2, el Mac visto desde el emulador).
      final xml = _sinComentariosXml(
        _leer('android/app/src/debug/res/xml/network_security_config.xml'),
      );
      expect(xml, contains('<base-config cleartextTrafficPermitted="false"'));
      final dominios = RegExp(r'<domain[^>]*>([^<]+)</domain>')
          .allMatches(xml)
          .map((m) => m.group(1)!.trim())
          .toSet();
      expect(dominios, {'localhost', '10.0.2.2'});
      // Ninguna otra variante trae su propia política.
      for (final variante in ['release', 'profile']) {
        expect(
          File('android/app/src/$variante/res/xml/network_security_config.xml')
              .existsSync(),
          isFalse,
          reason: variante,
        );
      }
    });
  });
}

String _leer(String ruta) {
  final archivo = File(ruta);
  expect(archivo.existsSync(), isTrue, reason: 'falta $ruta');
  return archivo.readAsStringSync();
}

/// Todos los AndroidManifest.xml de las variantes (main, debug, profile y
/// los que se agreguen).
List<String> _manifiestos() => Directory('android/app/src')
    .listSync()
    .whereType<Directory>()
    .map((d) => '${d.path}/AndroidManifest.xml')
    .where((ruta) => File(ruta).existsSync())
    .toList();

/// Un comentario que mencione un atributo no debe contar como si estuviera.
String _sinComentariosXml(String xml) =>
    xml.replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '');

String _sinComentariosKts(String kts) => kts
    .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
    .replaceAll(RegExp(r'//[^\n]*'), '');

/// El cuerpo de `buildTypes { release { … } }`, contando llaves para no
/// cortarse en el primer `}` interno (el `if` de la firma).
String _bloqueRelease(String kts) {
  final inicio =
      RegExp(r'buildTypes\s*\{[^{}]*?\brelease\s*\{').firstMatch(kts);
  expect(inicio, isNotNull, reason: 'no hay buildTypes { release { … } }');
  var nivel = 1;
  var i = inicio!.end;
  for (; i < kts.length && nivel > 0; i++) {
    if (kts[i] == '{') nivel++;
    if (kts[i] == '}') nivel--;
  }
  return kts.substring(inicio.end, i - 1);
}
