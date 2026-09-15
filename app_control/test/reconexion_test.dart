// Pruebas de volver a entrar muchas veces con el socket del paquete de verdad.
//
// Lo que se protege: `io.io` guarda un `Manager` por servidor y, sin
// `forceNew`, en cada llamada con la misma URL devuelve ese mismo `Manager`
// con su mismo socket, sin mirar las opciones nuevas. Cada `start()` del panel
// (entrar, volver a entrar cuando la sesión expiró, cambiar de backend) abre
// un servicio con el token de la sesión, pero el socket seguía siendo el
// primero y se presentaba con el primer token: el backend lo rechazaba y el
// panel volvía a «sesión expirada», o si entraba otra cuenta el socket seguía
// entrando con la de antes. Y el `onReconnectAttempt` de cada servicio muerto
// quedaba colgado del `Manager`.
//
// Sin red: los sockets son del paquete, con `autoConnect` apagado, y los
// eventos se disparan a mano. Cada prueba va a su propio puerto para no
// compartir con otra el `Manager` guardado.
import 'package:flutter_test/flutter_test.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:ya_viene_control/features/fleet/data/fleet_socket_service.dart';
import 'package:ya_viene_control/features/fleet/domain/fleet_bus.dart';

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
  test(
      'tras 100 entradas solo hay un socket, con el token de la última, y un '
      'oyente por evento', () async {
    final fabrica = _Fabrica();
    // Lo que hace `FleetNotifier.start()` en cada entrada: suelta el servicio
    // anterior y abre otro con el token de la sesión.
    FleetSocketService? anterior;
    for (var entrada = 1; entrada <= 100; entrada++) {
      anterior?.dispose();
      anterior = FleetSocketService(
        baseUrl: 'http://127.0.0.1:59201',
        token: 'tok-$entrada',
        crearSocket: fabrica.crear,
      )..connect();
    }
    final servicio = anterior!;
    final lotes = <List<FleetBus>>[];
    final conexion = <bool>[];
    final escuchas = [
      servicio.busBatchStream.listen(lotes.add),
      servicio.connectionStream.listen(conexion.add),
    ];

    final vivo = fabrica.creados.last;
    expect(vivo.auth, {'token': 'tok-100'});
    expect(fabrica.sockets('fleet:batch'), {vivo});
    expect(fabrica.gestores('reconnect_attempt'), {vivo.io});

    // Cada evento llega una vez, no una por entrada.
    vivo.emitReserved('fleet:batch', {
      'buses': [
        {'busId': 'B-1', 'companyId': 'c-1', 'routeId': 'R-1'},
      ],
    });
    vivo.io.emitReserved('reconnect_attempt', 1);
    await pumpEventQueue();
    expect(lotes, hasLength(1));
    expect(conexion, [false]);

    // Y al cerrar no queda nada colgado, ni del socket ni de su `Manager`.
    for (final escucha in escuchas) {
      await escucha.cancel();
    }
    servicio.dispose();
    expect(fabrica.sockets('fleet:batch'), isEmpty);
    expect(fabrica.gestores('reconnect_attempt'), isEmpty);
  });
}
