import 'dart:async';

import 'package:web_socket/web_socket.dart' show WebSocketConnectionClosed;

/// La zona donde el pasajero y el panel abren, reconectan y sueltan su
/// socket.
///
/// `socket_io_client` 3.1.6 (la última) cierra el WebSocket dos veces
/// cuando es el servidor el que corta —un panel con la contraseña cambiada,
/// un cliente que se pasó de eventos—: el `close` de `web_socket` ya llega
/// cerrado y su `Future` falla con [WebSocketConnectionClosed] sin que nadie
/// lo espere. Ese error suelto no cambia nada (la conexión ya estaba
/// cerrada), pero subía como error sin atender en cada expulsión: ruido en
/// el registro y, en las pruebas, una prueba roja (simulacro d de T10.5).
///
/// Esta zona se traga solo ese error y deja pasar todos los demás a la zona
/// que creó el servicio, igual que antes.
// ponytail: filtro por tipo; si el paquete lo arregla, se borra esta zona.
Zone zonaSocket() => Zone.current.fork(
      specification: ZoneSpecification(
        handleUncaughtError: (self, parent, zone, error, stack) {
          if (error is WebSocketConnectionClosed) return;
          parent.handleUncaughtError(zone, error, stack);
        },
      ),
    );
