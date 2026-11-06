// Pruebas de reconectar muchas veces con el socket del paquete de verdad.
//
// Lo que se protege: `io.io` guarda un `Manager` por servidor y, sin
// `forceNew`, en cada llamada con la misma URL devuelve ese mismo `Manager`
// con su mismo socket. Los `onReconnect*` se cuelgan del `Manager`, y el
// `dispose` del socket no los suelta: cada vuelta de conectar sumaba otro
// oyente, y un solo intento de reconexión avisaba «reconectando» tantas veces
// como vueltas llevaba la app.
//
// Sin red: los sockets son del paquete, con `autoConnect` apagado, y los
// eventos se disparan a mano. Cada prueba va a su propio puerto para no
// compartir con otra el `Manager` guardado.
import 'dart:async';
import 'dart:ui' show AppLifecycleState;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:ya_viene_core/ya_viene_core.dart';
import 'package:ya_viene_pasajero/core/providers/red_provider.dart';
import 'package:ya_viene_pasajero/features/map/data/services/realtime_service.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/realtime_providers.dart';

/// Abre los sockets del servicio con el paquete de verdad, sin conectarlos,
/// y se queda con todos.
class _Fabrica {
  final creados = <io.Socket>[];

  io.Socket crear(String url, Map<String, dynamic> opciones) {
    final socket = io.io(url, <String, dynamic>{
      ...opciones,
      'autoConnect': false,
    });
    creados.add(socket);
    return socket;
  }

  /// Los sockets distintos que siguen con algún oyente de [evento].
  Set<io.Socket> sockets(String evento) => {
        for (final socket in creados)
          if (socket.hasListeners(evento)) socket,
      };

  /// Los `Manager` distintos que siguen con algún oyente de [evento].
  Set<Object> gestores(String evento) => {
        for (final socket in creados)
          if (socket.io.hasListeners(evento)) socket.io,
      };
}

void main() {
  test('tras 100 reconexiones solo hay un socket y un oyente por evento',
      () async {
    final fabrica = _Fabrica();
    final servicio = RealtimeService(
      'http://127.0.0.1:59101',
      crearSocket: fabrica.crear,
    );
    final estados = <ConnectionStatus>[];
    final escucha = servicio.connectionStateStream.listen(estados.add);

    // Lo que hace la app al salir y volver a entrar, o al montar otra vez el
    // mapa, cien veces.
    servicio.connect();
    for (var vuelta = 0; vuelta < 100; vuelta++) {
      servicio
        ..disconnect()
        ..connect();
    }
    await pumpEventQueue();

    final vivo = fabrica.creados.last;
    expect(fabrica.sockets('bus:position'), {vivo});
    expect(fabrica.gestores('reconnect_attempt'), {vivo.io});
    expect(fabrica.gestores('reconnect_error'), {vivo.io});

    // Un intento de reconexión avisa una vez, no una por vuelta. El `Manager`
    // de esta versión del paquete no tapa `emit`: lo que se emite en él llega
    // a sus oyentes, como cuando reconecta de verdad.
    estados.clear();
    vivo.io.emit('reconnect_attempt', 1);
    vivo.io.emit('reconnect_error', 'no contesta');
    await pumpEventQueue();
    expect(estados, [
      ConnectionStatus.reconnecting,
      ConnectionStatus.disconnected,
    ]);

    // Y al cerrar no queda nada colgado, ni del socket ni de su `Manager`.
    await escucha.cancel();
    servicio.dispose();
    expect(fabrica.sockets('bus:position'), isEmpty);
    expect(fabrica.gestores('reconnect_attempt'), isEmpty);
    expect(fabrica.gestores('reconnect_error'), isEmpty);
  });

  // La sala de la ruta vive en el socket: uno que reconecta entra sin sala y
  // deja de recibir `bus:position`. Si la app no vuelve a pedir la sala en
  // cada conexión —no solo en la primera— el mapa se queda con los buses
  // parados donde estaban y el indicador en verde, que engaña más que un
  // «sin conexión».
  test('el pasajero vuelve a pedir su ruta en cada reconexión', () async {
    final fabrica = _Fabrica();
    final servicio = RealtimeService(
      'http://127.0.0.1:59102',
      crearSocket: fabrica.crear,
    )..connect();
    servicio.subscribeToRoute('R-101');
    final socket = fabrica.creados.single;

    // Sin transporte, lo que la app emite se queda en la cola de salida del
    // socket: ahí se ve qué pidió y cuántas veces.
    for (var vuelta = 1; vuelta <= 100; vuelta++) {
      // 'connect' y 'disconnect' son eventos reservados: `emit` los
      // rechaza, y el paquete los reparte con `emitReserved`, que es lo que
      // hace él mismo al conectar y al cerrarse el transporte.
      socket.emitReserved('connect');
      socket.emitReserved('disconnect', 'transport close');
    }
    await pumpEventQueue();

    // La primera es la de `subscribeToRoute`; las otras cien, una por
    // conexión.
    expect(_suscripciones(socket, 'R-101'), 101);
    expect(fabrica.creados, hasLength(1));

    servicio.dispose();
  });
  // «En el celular jode mucho para reconectar» (dueño, 2026-11-06): al volver
  // la app al frente, o la red, el socket esperaba su próximo reintento, que
  // con la espera creciente del paquete y el reintento de 15 s podían ser
  // 10 a 15 s más con el mapa quieto. Ahora se intenta en el acto.
  test('reconectar ya abre un socket nuevo si no hay conexión', () async {
    final fabrica = _Fabrica();
    final servicio = RealtimeService(
      'http://127.0.0.1:59103',
      crearSocket: fabrica.crear,
    )..connect();
    servicio.subscribeToRoute('R-101');

    servicio.reconectarYa();
    await pumpEventQueue();

    expect(fabrica.creados, hasLength(2));
    final viejo = fabrica.creados.first;
    expect(viejo.hasListeners('bus:position'), isFalse,
        reason: 'el socket viejo se suelta del todo');
    // El nuevo pide la sala de la ruta en cuanto conecta.
    final nuevo = fabrica.creados.last;
    nuevo.emitReserved('connect');
    await pumpEventQueue();
    expect(_suscripciones(nuevo, 'R-101'), 1);

    servicio.dispose();
  });

  test('reconectar ya no toca un socket conectado ni uno cerrado a propósito',
      () async {
    final fabrica = _Fabrica();
    final servicio = RealtimeService(
      'http://127.0.0.1:59104',
      crearSocket: fabrica.crear,
    )..connect();
    fabrica.creados.single.connected = true;

    servicio.reconectarYa();
    expect(fabrica.creados, hasLength(1), reason: 'ya estaba conectado');
    // Sin transporte de verdad, un socket «conectado» no puede despedirse.
    fabrica.creados.single.connected = false;

    servicio
      ..disconnect()
      ..reconectarYa();
    expect(fabrica.creados, hasLength(1),
        reason: 'la app soltó la conexión: no se abre otra');

    servicio
      ..dispose()
      ..reconectarYa();
    expect(fabrica.creados, hasLength(1));
  });
  test('volver al frente o volver la red reconecta en el acto', () async {
    final fabrica = _Fabrica();
    final red = StreamController<bool>();
    final contenedor = ProviderContainer(overrides: [
      backendUrlProvider
          .overrideWith(() => BackendUrl.fija('http://127.0.0.1:59105')),
      realtimeSocketFactoryProvider.overrideWithValue(fabrica.crear),
      hayRedProvider.overrideWith((ref) => red.stream),
    ]);
    addTearDown(() {
      contenedor.dispose();
      red.close();
    });
    contenedor.read(realtimeServiceProvider).connect();
    expect(fabrica.creados, hasLength(1));

    final vida = contenedor.read(appLifecycleProvider.notifier);
    vida.state = AppLifecycleState.paused;
    await pumpEventQueue();
    expect(fabrica.creados, hasLength(1), reason: 'en el fondo no se intenta');
    vida.state = AppLifecycleState.resumed;
    await pumpEventQueue();
    expect(fabrica.creados, hasLength(2), reason: 'de vuelta al frente');

    red.add(false);
    await pumpEventQueue();
    expect(fabrica.creados, hasLength(2), reason: 'sin red no hay a dónde');
    red.add(true);
    await pumpEventQueue();
    expect(fabrica.creados, hasLength(3), reason: 'volvió la red');
  });
}

/// Cuántas veces pidió el socket la sala de [routeId], leyendo su cola de
/// salida.
int _suscripciones(io.Socket socket, String routeId) =>
    socket.sendBuffer.where((p) {
      if (p is! Map || p['data'] is! List) return false;
      final datos = p['data'] as List;
      return datos.first == 'subscribe:route' && datos.last == routeId;
    }).length;
