import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Candado de los derechos (entitlements) del panel en macOS (T3.14).
///
/// El panel solo necesita salir a la red (HTTPS y el socket hacia el
/// backend), guardar la sesión en el llavero y escribir el CSV de Reportes
/// donde la persona elija en la ventana de guardar
/// (`files.user-selected.read-write`: solo ese archivo, nada más del disco). El llavero que usa es el
/// clásico (`usesDataProtectionKeychain: false` en auth_providers.dart), que
/// dentro del sandbox no pide ningún derecho: el de protección de datos sí
/// exige `keychain-access-groups`, y con la firma «ad hoc» ese derecho da
/// -34018 y no se guardaba nada. Por eso aquí la lista es exacta: cualquier
/// derecho de más (cámara, carpetas enteras, servidor, `keychain-access-groups`) es
/// superficie que nadie pidió, y cualquiera de menos (sin sandbox, sin red)
/// es un panel que no sirve o que corre suelto.
///
/// Se leen los archivos tal como están en el repositorio; `flutter test`
/// corre con el paquete como directorio de trabajo.
void main() {
  const runner = 'macos/Runner';

  test(
    'Release.entitlements: sandbox, red de cliente y el archivo elegido',
    () {
      expect(_derechos('$runner/Release.entitlements'), {
        'com.apple.security.app-sandbox': true,
        'com.apple.security.network.client': true,
        'com.apple.security.files.user-selected.read-write': true,
      });
    },
  );

  test(
    'DebugProfile.entitlements: lo de release más lo que pide flutter run',
    () {
      // allow-jit: el motor de Dart compila en caliente en debug.
      // network.server: la herramienta de Flutter se conecta al servicio de la
      // VM de Dart (depurador, recarga en caliente) que escucha en la app.
      // Ninguno de los dos llega al .app de release.
      expect(_derechos('$runner/DebugProfile.entitlements'), {
        'com.apple.security.app-sandbox': true,
        'com.apple.security.cs.allow-jit': true,
        'com.apple.security.network.client': true,
        'com.apple.security.files.user-selected.read-write': true,
        'com.apple.security.network.server': true,
      });
    },
  );

  test(
    'la configuración Release del proyecto firma con Release.entitlements',
    () {
      // Si el proyecto de Xcode apuntara Release a DebugProfile, la prueba de
      // arriba cuidaría un archivo que nadie usa.
      final pbx = File(
        'macos/Runner.xcodeproj/project.pbxproj',
      ).readAsStringSync();
      final porConfiguracion = <String, String>{};
      for (final m in RegExp(
        r'CODE_SIGN_ENTITLEMENTS = ([^;]+);.*?\bname = (\w+);',
        dotAll: true,
      ).allMatches(pbx)) {
        porConfiguracion[m.group(2)!] = m.group(1)!.trim();
      }
      expect(porConfiguracion, {
        'Debug': 'Runner/DebugProfile.entitlements',
        'Profile': 'Runner/DebugProfile.entitlements',
        'Release': 'Runner/Release.entitlements',
      });
    },
  );

  test('Info.plist de macOS no abre ATS', () {
    // Igual que en el pasajero: el backend es HTTPS y una URL http debe
    // fallar a la vista, no salir en claro con la clave del panel.
    expect(
      File('$runner/Info.plist').readAsStringSync(),
      isNot(contains('NSAllowsArbitraryLoads')),
    );
  });
}

/// Los pares `<key>…</key><true/|false/>` del plist. Un valor que no sea
/// booleano (un arreglo de grupos de llavero, por ejemplo) entra como su
/// texto crudo, y así también rompe la igualdad exacta.
Map<String, Object> _derechos(String ruta) {
  final plist = File(ruta).readAsStringSync();
  final dict = RegExp(
    r'<plist[^>]*>\s*<dict>(.*)</dict>\s*</plist>',
    dotAll: true,
  ).firstMatch(plist);
  expect(dict, isNotNull, reason: '$ruta no es un plist con <dict>');
  final cuerpo = dict!.group(1)!;
  final derechos = <String, Object>{};
  final claves = RegExp(r'<key>([^<]+)</key>').allMatches(cuerpo).toList();
  for (var i = 0; i < claves.length; i++) {
    final fin = i + 1 < claves.length ? claves[i + 1].start : cuerpo.length;
    final valor = cuerpo.substring(claves[i].end, fin).trim();
    derechos[claves[i].group(1)!] = switch (valor) {
      '<true/>' => true,
      '<false/>' => false,
      _ => valor,
    };
  }
  return derechos;
}
