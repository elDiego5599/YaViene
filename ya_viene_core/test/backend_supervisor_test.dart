// Pruebas de cuándo se vuelve a elegir backend con la app abierta.
//
// Lo que se protege: si el túnel se cae con la app abierta, la app tiene que
// irse sola al respaldo, pero sin cambiar de sitio cada vez que la conexión
// parpadea ni lanzar una pregunta encima de otra.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

const principal = 'https://tunel.ngrok-free.dev';
const respaldo = 'https://ya-viene-backend.fly.dev';

void main() {
  // Las del supervisor van con `testWidgets` por el reloj de mentira: las
  // esperas de 30 s pasan con `pump`, sin esperarlas de verdad.
  testWidgets('sin conexión 30 s vuelve a preguntar, y no antes',
      (tester) async {
    var preguntas = 0;
    final supervisor = BackendSupervisor(reResolver: () async {
      preguntas++;
    });

    supervisor.conexionPerdida();
    await tester.pump(const Duration(seconds: 29));
    expect(preguntas, 0);
    // Otro aviso del mismo corte no reinicia la cuenta.
    supervisor.conexionPerdida();
    await tester.pump(const Duration(seconds: 1));
    expect(preguntas, 1);

    supervisor.dispose();
  });

  testWidgets(
      'si la conexión vuelve antes, o la app cierra el socket, no pregunta',
      (tester) async {
    var preguntas = 0;
    final supervisor = BackendSupervisor(reResolver: () async {
      preguntas++;
    });

    supervisor.conexionPerdida();
    await tester.pump(const Duration(seconds: 20));
    supervisor.conexionRecuperada();
    await tester.pump(const Duration(minutes: 5));
    expect(preguntas, 0);

    supervisor.conexionPerdida();
    await tester.pump(const Duration(seconds: 20));
    supervisor.detener();
    await tester.pump(const Duration(minutes: 5));
    expect(preguntas, 0);

    supervisor.dispose();
  });

  testWidgets(
      'mientras pregunta no lanza otra pregunta, y si sigue caído vuelve a '
      'contar', (tester) async {
    var preguntas = 0;
    final supervisor = BackendSupervisor(reResolver: () async {
      preguntas++;
      // Lo que tarda de verdad con los dos caídos: 3 s por la principal y
      // 20 s por el respaldo.
      await Future<void>.delayed(const Duration(seconds: 23));
    });

    supervisor.conexionPerdida();
    await tester.pump(const Duration(seconds: 30));
    expect(preguntas, 1);
    // Siguen llegando avisos de caída mientras pregunta.
    supervisor.conexionPerdida();
    await tester.pump(const Duration(seconds: 23));
    expect(preguntas, 1);
    // Terminó y sigue sin conexión: la cuenta empieza de cero.
    await tester.pump(const Duration(seconds: 29));
    expect(preguntas, 1);
    await tester.pump(const Duration(seconds: 1));
    expect(preguntas, 2);

    supervisor.dispose();
    // La segunda pregunta sigue en vuelo: se deja terminar para que no quede
    // un temporizador vivo al cerrar la prueba, y ya cerrado no vuelve a
    // contar.
    await tester.pump(const Duration(seconds: 23));
    await tester.pump(const Duration(minutes: 5));
    expect(preguntas, 2);
  });

  // Riesgo: si la conexión vuelve mientras se pregunta, al terminar la
  // pregunta no hay nada que vigilar; contar otra vez mandaría la app a
  // preguntar cada 30 s con todo andando.
  testWidgets('si la conexión vuelve durante la pregunta, no vuelve a contar',
      (tester) async {
    var preguntas = 0;
    final supervisor = BackendSupervisor(reResolver: () async {
      preguntas++;
      await Future<void>.delayed(const Duration(seconds: 23));
    });

    supervisor.conexionPerdida();
    await tester.pump(const Duration(seconds: 30));
    expect(preguntas, 1);
    await tester.pump(const Duration(seconds: 10));
    supervisor.conexionRecuperada();
    await tester.pump(const Duration(seconds: 13));
    await tester.pump(const Duration(minutes: 5));
    expect(preguntas, 1);

    supervisor.dispose();
  });

  // Riesgo: un aviso de caída que llega tras cerrar (el socket muere al
  // salir) arrancaría una cuenta que pregunta con la app ya cerrada.
  testWidgets('cerrado, un aviso de caída no arranca la cuenta',
      (tester) async {
    var preguntas = 0;
    final supervisor = BackendSupervisor(reResolver: () async {
      preguntas++;
    });

    supervisor.dispose();
    supervisor.conexionPerdida();
    await tester.pump(const Duration(minutes: 5));
    expect(preguntas, 0);
  });

  test('reResolver solo cambia la URL cuando la respuesta es otra', () async {
    var vivas = {principal};
    final container = ProviderContainer(overrides: [
      backendUrlProvider.overrideWith(() => BackendUrl(
            principal,
            principal: principal,
            respaldo: respaldo,
            sonda: (url, _) async => vivas.contains(url),
          )),
    ]);
    addTearDown(container.dispose);
    final cambios = <String>[];
    container.listen<String>(backendUrlProvider, (_, url) => cambios.add(url));

    await container.read(backendUrlProvider.notifier).reResolver();
    expect(cambios, isEmpty);

    vivas = {respaldo};
    await container.read(backendUrlProvider.notifier).reResolver();
    expect(cambios, [respaldo]);
    expect(container.read(backendUrlProvider), respaldo);
  });

  group('vuelta a la principal', () {
    ({ProviderContainer container, Set<String> vivas, List<String> preguntadas})
        montar(String inicial, Set<String> vivas) {
      final preguntadas = <String>[];
      final container = ProviderContainer(overrides: [
        backendUrlProvider.overrideWith(() => BackendUrl(
              inicial,
              principal: principal,
              respaldo: respaldo,
              sonda: (url, _) async {
                preguntadas.add(url);
                return vivas.contains(url);
              },
            )),
      ]);
      container.read(backendUrlProvider);
      return (container: container, vivas: vivas, preguntadas: preguntadas);
    }

    testWidgets('en el respaldo, vuelve sola a la principal cuando contesta',
        (tester) async {
      // Antes, una vez en el respaldo, la app se quedaba en la flota
      // simulada toda la sesión aunque ngrok reviviera (dueño, 2026-10-26).
      final m = montar(respaldo, {respaldo});
      addTearDown(m.container.dispose);

      await tester.pump(BackendUrl.vueltaCada);
      expect(m.container.read(backendUrlProvider), respaldo);
      expect(m.preguntadas, [principal]);

      m.vivas.add(principal);
      await tester.pump(BackendUrl.vueltaCada);
      expect(m.container.read(backendUrlProvider), principal);

      // De vuelta en la principal no se sigue preguntando.
      final antes = m.preguntadas.length;
      await tester.pump(BackendUrl.vueltaCada * 3);
      expect(m.preguntadas.length, antes);
    });

    testWidgets('caer al respaldo con la app abierta también vigila la vuelta',
        (tester) async {
      final m = montar(principal, {respaldo});
      addTearDown(m.container.dispose);
      await m.container.read(backendUrlProvider.notifier).reResolver();
      expect(m.container.read(backendUrlProvider), respaldo);

      m.vivas.add(principal);
      await tester.pump(BackendUrl.vueltaCada);
      expect(m.container.read(backendUrlProvider), principal);
    });

    testWidgets('en la principal no se pregunta nada', (tester) async {
      final m = montar(principal, {principal, respaldo});
      addTearDown(m.container.dispose);
      await tester.pump(BackendUrl.vueltaCada * 3);
      expect(m.preguntadas, isEmpty);
    });

    testWidgets('tras cerrar, ya no pregunta', (tester) async {
      final m = montar(respaldo, {respaldo});
      m.container.dispose();
      await tester.pump(BackendUrl.vueltaCada * 3);
      expect(m.preguntadas, isEmpty);
    });
  });
}
