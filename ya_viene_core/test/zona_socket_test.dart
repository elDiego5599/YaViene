import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:web_socket/web_socket.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

void main() {
  test('se traga el doble cierre del WebSocket y nada más', () async {
    final sueltos = <Object>[];
    await runZonedGuarded(() async {
      final zona = zonaSocket();
      // Lo que hace socket_io_client cuando el servidor corta primero: un
      // `close()` sobre un WebSocket ya cerrado, cuyo Future nadie espera.
      zona.run(() => Future<void>.error(WebSocketConnectionClosed()));
      // Cualquier otro error sigue llegando a quien creó el servicio.
      zona.run(() => Future<void>.error(StateError('otro')));
      await Future<void>.delayed(Duration.zero);
    }, (error, _) => sueltos.add(error));
    expect(sueltos, hasLength(1));
    expect(sueltos.single, isA<StateError>());
  });
}
