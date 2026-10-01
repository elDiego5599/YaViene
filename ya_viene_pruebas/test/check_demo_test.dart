import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_pruebas/backend_temporal.dart';

/// `check-demo.sh`, el pre-vuelo del día del pitch (T10.3).
///
/// El servidor se revisa contra un backend temporal con su flota demo: el
/// vivo y el túnel no se tocan. Lo del Mac (launchd, corriente, sueño) es
/// del Mac donde corre y no se puede fingir; sí se prueba lo que depende de
/// archivos: la edad de la última copia y el tamaño de los logs.
void main() {
  const script = '../check-demo.sh';
  final backendDir = BackendTemporal.buscar();
  final sinSqlite = Process.runSync('which', ['sqlite3']).exitCode != 0;

  Future<ProcessResult> correr(List<String> args, Map<String, String> env) =>
      Process.run('bash', [script, ...args], environment: env);

  group('servidor', () {
    BackendTemporal? backend;
    setUpAll(() async {
      if (backendDir != null && !sinSqlite) {
        backend = await BackendTemporal.arrancar(backendDir);
      }
    });
    tearDownAll(() async => backend?.parar());

    test('con el backend listo y la flota publicando, todo en verde',
        () async {
      final r = await correr(
        ['--sin-mac'],
        {'URL': backend!.url, 'DB': backend!.rutaBase},
      );
      expect(r.stdout, contains('✔ Backend listo'));
      expect(r.stdout, contains('✔ Buses publicando en R-106'));
      expect(r.stdout, contains('posición en la base hace'));
      expect(r.stdout, isNot(contains('✗')));
      expect(r.exitCode, 0);
    }, timeout: const Timeout(Duration(minutes: 1)));

    test('sin backend que conteste, falla y dice dónde mirar', () async {
      final libre = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final puerto = libre.port;
      await libre.close();
      final r = await correr(
        ['--sin-mac'],
        {'URL': 'http://127.0.0.1:$puerto', 'DB': backend!.rutaBase},
      );
      expect(r.stdout, contains('✗ El túnel o el backend NO están listos'));
      expect(r.exitCode, 1);
    });
  }, skip: backendDir == null || sinSqlite
      ? 'sin YaVieneBackend al lado o sin sqlite3'
      : false);

  group('este Mac', () {
    late Directory tmp;
    setUp(() async => tmp = await Directory.systemTemp.createTemp('pre-'));
    tearDown(() => tmp.deleteSync(recursive: true));

    Future<String> soloMac() async {
      final r = await correr(['--solo-mac'], {
        'RESPALDOS': tmp.path,
        'LOGS': tmp.path,
      });
      return r.stdout as String;
    }

    test('una copia de hace 3 h no cuenta; una de ahora sí', () async {
      final copia = File('${tmp.path}/yaviene-20261001-100000.db')
        ..writeAsStringSync('x')
        ..setLastModifiedSync(
          DateTime.now().subtract(const Duration(hours: 3)),
        );
      expect(await soloMac(), contains('✗ No hay copia de menos de 2 h'));

      copia.setLastModifiedSync(DateTime.now());
      expect(
        await soloMac(),
        contains('✔ Copia reciente: yaviene-20261001-100000.db'),
      );
    });

    test('un log de más de 50 MB delata la rotación caída', () async {
      expect(await soloMac(), contains('✔ Logs por debajo de 50 MB'));
      // Disperso: ocupa 51 MB de tamaño, no de disco.
      final log = File('${tmp.path}/backend.log').openSync(mode: FileMode.write)
        ..truncateSync(51 * 1024 * 1024);
      log.closeSync();
      expect(await soloMac(), contains('✗ Logs de más de 50 MB'));
      expect(await soloMac(), contains('backend.log'));
    });
  }, skip: Platform.isMacOS ? false : 'launchctl y pmset son de macOS');
}
