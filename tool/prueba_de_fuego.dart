// Prueba de fuego: rompe el código a propósito y mira si las pruebas lo notan.
//
// Que la suite pase no dice que cuide algo: una prueba que nunca falla
// tampoco falla cuando el código se rompe. Cada mutación de
// `tool/prueba-de-fuego.json` es un error creíble en una pieza que importa
// —un `<` que pasa a `<=`, un tope que crece, un filtro que desaparece—; se
// aplica, se corre `flutter test` en el paquete dueño del archivo y se
// deshace. Si sigue en verde con el error puesto, la mutación «sobrevive» y
// falta una prueba. Lo de `ya_viene_core` lo usan las dos apps: si el core no
// lo nota, se prueba también contra el pasajero y el panel.
//
// Uso (desde la raíz del repo):
//   dart tool/prueba_de_fuego.dart              # todas (≈1–3 min cada una)
//   dart tool/prueba_de_fuego.dart --solo=3,7   # solo esas (su número)
//
// Se niega a correr con cambios sin commitear en los archivos que muta, para
// que deshacer sea volver al archivo tal como estaba.
// `ya_viene_pruebas/test/prueba_de_fuego_test.dart` vigila que cada mutación
// siga aplicando: si alguien cambia la línea, la lista no se pudre en
// silencio.
import 'dart:convert';
import 'dart:io';

enum Resultado { pasa, falla, noCorrio }

Resultado correr(String paquete) {
  final r = Process.runSync(
    'flutter',
    ['test', '--no-pub'],
    workingDirectory: paquete,
    runInShell: true,
  );
  final salida = '${r.stdout}${r.stderr}';
  // Sin la línea final de `flutter test` no se sabe si corrió algo: un
  // error del entorno no puede contar como «muere».
  if (salida.contains('All tests passed!') && r.exitCode == 0) {
    return Resultado.pasa;
  }
  if (salida.contains('Some tests failed.')) return Resultado.falla;
  return Resultado.noCorrio;
}

List<String> paquetesDe(String archivo) {
  final paquete = archivo.split('/').first;
  return paquete == 'ya_viene_core'
      ? ['ya_viene_core', 'app_pasajero', 'app_control']
      : [paquete];
}

void main(List<String> args) {
  final lista =
      (jsonDecode(File('tool/prueba-de-fuego.json').readAsStringSync()) as List)
          .cast<Map<String, dynamic>>();
  final archivos = {for (final m in lista) m['archivo'] as String};
  final sucio = Process.runSync('git', [
    'status',
    '--porcelain',
    '--',
    ...archivos,
  ]);
  if (sucio.exitCode != 0 || (sucio.stdout as String).trim().isNotEmpty) {
    stderr.writeln(
      'Hay cambios sin commitear en los archivos que se mutan: '
      'la prueba de fuego no corre así.',
    );
    exit(2);
  }
  final soloArg = args.where((a) => a.startsWith('--solo=')).firstOrNull;
  final solo = soloArg?.substring(7).split(',').map(int.parse).toSet();

  File? actual;
  String? original;
  void deshacer() {
    final (archivo, texto) = (actual, original);
    if (archivo != null && texto != null) archivo.writeAsStringSync(texto);
  }

  for (final senal in [ProcessSignal.sigint, ProcessSignal.sigterm]) {
    senal.watch().listen((_) {
      deshacer();
      exit(130);
    });
  }

  final malas = <String>[];
  var corridas = 0;
  for (var i = 0; i < lista.length; i++) {
    final n = i + 1;
    if (solo != null && !solo.contains(n)) continue;
    final m = lista[i];
    final archivo = m['archivo'] as String;
    final de = m['de'] as String;
    actual = File(archivo);
    original = actual.readAsStringSync();
    if (original.split(de).length != 2) {
      throw StateError('#$n no aplica: «$de» no está una sola vez en $archivo');
    }
    corridas++;
    final reloj = Stopwatch()..start();
    var resultado = Resultado.pasa;
    try {
      actual.writeAsStringSync(original.replaceFirst(de, m['a'] as String));
      for (final paquete in paquetesDe(archivo)) {
        resultado = correr(paquete);
        if (resultado != Resultado.pasa) break;
      }
    } finally {
      deshacer();
      original = null;
    }
    final rotulo = switch (resultado) {
      Resultado.pasa => 'SOBREVIVE',
      Resultado.falla => 'muere    ',
      Resultado.noCorrio => 'NO CORRIÓ',
    };
    print(
      '$rotulo  #${n.toString().padLeft(2)}  ${m['que']}  '
      '(${reloj.elapsed.inSeconds} s)',
    );
    if (resultado != Resultado.falla) malas.add('  #$n $archivo: ${m['que']}');
  }
  print(
    '\n${corridas - malas.length} de $corridas mutaciones las detecta la '
    'suite.',
  );
  if (malas.isNotEmpty) {
    print('Sin prueba que las note, o sin correr:');
    malas.forEach(print);
    exit(1);
  }
  exit(0);
}
