import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import 'package:ya_viene_pasajero/features/map/data/services/realtime_service.dart';
import 'package:ya_viene_pruebas/backend_temporal.dart';

/// Simulacro b de T10.5 con el pasajero, contra un backend de verdad.
///
/// No corre con la suite: arranca un backend con su flota demo. Se pide con
/// `YAVIENE_SIMULACROS=1` (`tool/simulacros.sh`). Usa un backend temporal en
/// puertos libres: el vivo, su base y el túnel no se tocan.
void main() {
  final dir = BackendTemporal.buscar();
  final skip = Platform.environment['YAVIENE_SIMULACROS'] != '1'
      ? 'simulacro: YAVIENE_SIMULACROS=1 (tool/simulacros.sh)'
      : dir == null
          ? 'simulacro: no está YaVieneBackend al lado (o YAVIENE_BACKEND)'
          : null;

  test('b · el backend se reinicia y el pasajero vuelve a ver su ruta',
      () async {
    final backend = await BackendTemporal.arrancar(dir!);
    addTearDown(backend.parar);
    final pasajero = RealtimeService(backend.url);
    addTearDown(pasajero.dispose);

    // La ruta que mira el pasajero de la demo (la rápida de la flota).
    const ruta = 'R-106';
    Future<void> posicionDe106() => pasajero.busPositionStream
        .firstWhere((p) => p['routeId'] == ruta)
        .timeout(const Duration(seconds: 30));

    // Se suscribe ya conectado: la primera vez la pide la pantalla, no el
    // servicio al conectar.
    final conectado = pasajero.connectionStateStream
        .firstWhere((s) => s == ConnectionStatus.connected);
    pasajero.connect();
    await conectado.timeout(const Duration(seconds: 10));
    final primera = posicionDe106();
    pasajero.subscribeToRoute(ruta);
    await primera;

    final caida = pasajero.connectionStateStream
        .firstWhere((s) => s != ConnectionStatus.connected);
    final reloj = Stopwatch()..start();
    await backend.reiniciar();
    await caida.timeout(const Duration(seconds: 5));

    // Nadie vuelve a pedir la ruta: el servicio se suscribe solo al
    // reconectar y las posiciones de R-106 vuelven a llegar.
    await pasajero.connectionStateStream
        .firstWhere((s) => s == ConnectionStatus.connected)
        .timeout(const Duration(seconds: 30));
    await posicionDe106();
    reloj.stop();
    // ignore: avoid_print
    print('simulacro b (pasajero): de vuelta con posiciones de $ruta en '
        '${reloj.elapsedMilliseconds} ms desde la orden de reinicio');
  }, skip: skip, timeout: const Timeout(Duration(minutes: 2)));
}
