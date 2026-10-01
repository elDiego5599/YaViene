import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_control/features/fleet/data/fleet_socket_service.dart';
import 'package:ya_viene_pruebas/backend_temporal.dart';

/// Simulacros b y d de T10.5 con el panel, contra un backend de verdad.
///
/// No corren con la suite: arrancan un backend (con su flota demo) y el d
/// espera el minuto de revisión de producción. Se piden con
/// `YAVIENE_SIMULACROS=1` (`tool/simulacros.sh`). Usan un backend temporal
/// en puertos libres: el vivo, su base y el túnel no se tocan.
void main() {
  final dir = BackendTemporal.buscar();
  final skip = Platform.environment['YAVIENE_SIMULACROS'] != '1'
      ? 'simulacro: YAVIENE_SIMULACROS=1 (tool/simulacros.sh)'
      : dir == null
          ? 'simulacro: no está YaVieneBackend al lado (o YAVIENE_BACKEND)'
          : null;

  const empresa = 'EMP-01';
  const usuario = 'simulacro';

  late BackendTemporal backend;
  setUp(() async {
    backend = await BackendTemporal.arrancar(dir!);
    await backend.guardarAdmin(empresa, usuario, 'primera-clave-1');
  });
  tearDown(() => backend.parar());

  test('b · el backend se reinicia y el panel vuelve solo a ver la flota',
      () async {
    final token = await backend.entrar(usuario, 'primera-clave-1');
    final panel = FleetSocketService(baseUrl: backend.url, token: token);
    addTearDown(panel.dispose);
    var expulsado = false;
    panel.sessionKickedStream.listen((_) => expulsado = true);

    final primerLote = panel.busBatchStream.first;
    panel.connect();
    expect(await primerLote.timeout(const Duration(seconds: 15)), isNotEmpty);

    final caida = panel.connectionStream.firstWhere((c) => !c);
    final reloj = Stopwatch()..start();
    await backend.reiniciar();
    await caida.timeout(const Duration(seconds: 5));

    // Vuelve sin que nadie toque nada: reconecta, se suscribe de nuevo a la
    // flota y le llegan otra vez posiciones de los buses.
    await panel.connectionStream
        .firstWhere((c) => c)
        .timeout(const Duration(seconds: 30));
    await panel.busPositionStream.first.timeout(const Duration(seconds: 30));
    reloj.stop();
    // Un reinicio no es una sesión revocada: el panel no pide la contraseña.
    expect(expulsado, isFalse);
    // ignore: avoid_print
    print('simulacro b (panel): de vuelta con posiciones en '
        '${reloj.elapsedMilliseconds} ms desde la orden de reinicio');
  }, skip: skip, timeout: const Timeout(Duration(minutes: 2)));

  test('d · cambiar la contraseña con el panel abierto lo saca en ≤ 60 s',
      () async {
    final viejo = await backend.entrar(usuario, 'primera-clave-1');
    final panel = FleetSocketService(baseUrl: backend.url, token: viejo);
    addTearDown(panel.dispose);
    final primerLote = panel.busBatchStream.first;
    panel.connect();
    await primerLote.timeout(const Duration(seconds: 15));

    final expulsion = panel.sessionKickedStream.first;
    // Lo que haría el dueño: el mismo script, con otra contraseña. El reloj
    // corre desde que el cambio quedó en la base.
    await backend.guardarAdmin(empresa, usuario, 'segunda-clave-2');
    final reloj = Stopwatch()..start();
    // El backend revisa los paneles conectados cada minuto (el valor de
    // producción: aquí no se acorta).
    await expulsion.timeout(const Duration(seconds: 65));
    reloj.stop();
    expect(reloj.elapsed, lessThanOrEqualTo(const Duration(seconds: 61)));

    // El token viejo no vuelve a entrar: el backend lo saca al suscribirse.
    final otro = FleetSocketService(baseUrl: backend.url, token: viejo);
    addTearDown(otro.dispose);
    final otraExpulsion = otro.sessionKickedStream.first;
    otro.connect();
    await otraExpulsion.timeout(const Duration(seconds: 10));

    // Y la contraseña nueva sí.
    final nuevo = await backend.entrar(usuario, 'segunda-clave-2');
    final vuelta = FleetSocketService(baseUrl: backend.url, token: nuevo);
    addTearDown(vuelta.dispose);
    final lote = vuelta.busBatchStream.first;
    vuelta.connect();
    expect(await lote.timeout(const Duration(seconds: 15)), isNotEmpty);
    // ignore: avoid_print
    print('simulacro d: panel expulsado a los '
        '${reloj.elapsedMilliseconds} ms del cambio de contraseña');
  }, skip: skip, timeout: const Timeout(Duration(minutes: 3)));
}
