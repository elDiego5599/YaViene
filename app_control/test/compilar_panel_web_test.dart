// `tool/compilar-panel-web.sh`: la CSP con que se sirve el panel web y la
// revisión de que la build no pide CanvasKit a gstatic. La compilación
// entera no corre aquí (tarda y pide el SDK web); estas son las dos partes
// que se pudren solas si nadie las mira.
@TestOn('mac-os || linux')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _script = '../tool/compilar-panel-web.sh';

ProcessResult _correr(List<String> args) =>
    Process.runSync('bash', [_script, ...args]);

void main() {
  group('--csp', () {
    test('con https, la API y su wss van en connect-src', () {
      final r = _correr(['--csp', 'https://api.ejemplo.co']);

      expect(r.exitCode, 0, reason: '${r.stderr}');
      final csp = (r.stdout as String).trim();
      expect(
        csp,
        contains(
          "connect-src 'self' https://api.ejemplo.co wss://api.ejemplo.co ",
        ),
      );
    });

    test('con localhost y puerto, ws en vez de wss', () {
      final r = _correr(['--csp', 'http://localhost:3413']);

      expect(r.exitCode, 0, reason: '${r.stderr}');
      expect(r.stdout, contains('http://localhost:3413 ws://localhost:3413 '));
    });

    // Lo que se midió en el navegador (FALTANTES, alojamiento del panel).
    test('sin unsafe-eval, con wasm-unsafe-eval y lo que pide el mapa', () {
      final csp = _correr(['--csp', 'https://api.ejemplo.co']).stdout as String;
      final directivas = {
        for (final d in csp.trim().split(';'))
          d.trim().split(' ').first: d.trim(),
      };

      expect(directivas['script-src'], "script-src 'self' 'wasm-unsafe-eval'");
      expect(csp, isNot(contains("'unsafe-eval'")));
      expect(directivas['style-src'], "style-src 'self' 'unsafe-inline'");
      expect(directivas['font-src'], contains('https://fonts.gstatic.com'));
      expect(directivas['img-src'], contains('https://*.cartocdn.com'));
      expect(directivas['connect-src'], contains('https://fonts.gstatic.com'));
      expect(directivas['connect-src'], contains('https://*.cartocdn.com'));
      expect(directivas['frame-ancestors'], "frame-ancestors 'none'");
      expect(directivas['object-src'], "object-src 'none'");
    });

    for (final malo in const [
      'http://api.ejemplo.co',
      'https://api.ejemplo.co/',
      'https://api.ejemplo.co/api',
      'https://*.ejemplo.co',
      "https://a.co; script-src 'unsafe-eval'",
      '',
    ]) {
      test('«$malo» no es un origen y no sale CSP', () {
        final r = _correr(['--csp', malo]);

        expect(r.exitCode, 2);
        expect(r.stdout, isEmpty);
      });
    }

    // El bash 3.2 de macOS, en un locale UTF-8, leía «$api» como una variable
    // `api` seguida del primer byte de «»» y moría con «unbound variable»
    // antes de decir qué estaba mal (AUD16-02).
    test('el error dice qué origen sobra también en un locale UTF-8', () {
      final r = Process.runSync(
        '/bin/bash',
        [_script, '--csp', 'http://api.ejemplo.co'],
        environment: {'LC_ALL': 'en_US.UTF-8'},
      );

      expect(r.exitCode, 2, reason: '${r.stderr}');
      expect(r.stderr, contains('«http://api.ejemplo.co» no es un origen'));
    });
  });

  group('--revisar', () {
    late Directory build;

    setUp(() {
      build = Directory.systemTemp.createTempSync('panel-web');
      addTearDown(() => build.deleteSync(recursive: true));
    });

    void armar({required bool local, bool wasm = true}) {
      if (wasm) {
        File('${build.path}/canvaskit/canvaskit.wasm')
          ..createSync(recursive: true)
          ..writeAsStringSync('');
      }
      File('${build.path}/flutter_bootstrap.js').writeAsStringSync(
        '_flutter.buildConfig = {"engineRevision":"x","builds":[],'
        '"useLocalCanvasKit":$local};',
      );
    }

    test('una build con su CanvasKit pasa', () {
      armar(local: true);

      expect(_correr(['--revisar', build.path]).exitCode, 0);
    });

    test('una build que pide CanvasKit a gstatic falla', () {
      armar(local: false);

      final r = _correr(['--revisar', build.path]);
      expect(r.exitCode, 1);
      expect(r.stderr, contains('--no-web-resources-cdn'));
    });

    test('sin canvaskit.wasm en la carpeta falla', () {
      armar(local: true, wasm: false);

      expect(_correr(['--revisar', build.path]).exitCode, 1);
    });
  });

  // Lo que se le pasa a `flutter build web --base-href`: tiene que empezar
  // y terminar en «/». Se revisa antes de compilar, así que aquí no compila.
  group('--base-href', () {
    for (final malo in const ['panel/', '/panel', 'panel', '/pa nel/', '//']) {
      test('«$malo» no es una base y no compila', () {
        final r = _correr(['--base-href', malo, 'https://api.ejemplo.co']);

        expect(r.exitCode, 2);
        expect(r.stderr, contains('--base-href'));
      });
    }

    for (final resto in const [
      <String>[],
      ['--csp', 'https://api.ejemplo.co'],
    ]) {
      test(
        'con ${resto.isEmpty ? 'nada' : resto.first} detrás dice cómo se usa',
        () {
          final r = _correr(['--base-href', '/panel/', ...resto]);

          expect(r.exitCode, 2);
          expect(r.stderr, contains('Uso:'));
          expect(r.stdout, isEmpty);
        },
      );
    }
  });

  test('sin argumentos dice cómo se usa', () {
    final r = _correr([]);

    expect(r.exitCode, 2);
    expect(r.stderr, contains('Uso:'));
  });
}
