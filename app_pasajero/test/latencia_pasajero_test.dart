// T7.6: el pasajero apunta cuánto tardó en llegarle cada posición.
//
// Los eventos entran por el socket de verdad del paquete, sin conectar, con
// `emitEvent`, que es por donde pasa un paquete que llega del servidor.
import 'package:flutter_test/flutter_test.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:ya_viene_core/ya_viene_core.dart';
import 'package:ya_viene_pasajero/features/map/data/services/realtime_service.dart';

Map<String, dynamic> _posicion({
  required int capturado,
  required int emitido,
  String busId = 'BUS-ABC123',
}) =>
    {
      'busId': busId,
      'routeId': 'R-101',
      'lat': 10.988,
      'lon': -74.789,
      'speedKmh': 20.0,
      'heading': 90.0,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'capturedAt': capturado,
      'emittedAt': emitido,
      'isGhost': false,
    };

void main() {
  test('cada posición que llega deja su muestra de latencia', () {
    final medidor = MedidorLatencia();
    late io.Socket socket;
    final servicio = RealtimeService(
      'http://127.0.0.1:59161',
      medidor: medidor,
      crearSocket: (url, opciones) => socket = io.io(url, <String, dynamic>{
        ...opciones,
        'autoConnect': false,
      }),
    );
    addTearDown(servicio.dispose);
    servicio.connect();

    final ahora = DateTime.now().millisecondsSinceEpoch;
    socket.emitEvent([
      'positions:batch',
      {
        'routeId': 'R-101',
        'buses': [
          _posicion(capturado: ahora - 900, emitido: ahora - 100),
          _posicion(
            capturado: ahora - 800,
            emitido: ahora - 50,
            busId: 'BUS-DEF456',
          ),
        ],
      },
    ]);
    expect(medidor.resumen.muestrasEmision, 2);

    socket.emitEvent([
      'bus:position',
      _posicion(capturado: ahora, emitido: ahora),
    ]);
    expect(medidor.resumen.muestrasEmision, 3);

    socket.emitEvent([
      'positions:update',
      {
        'routeId': 'R-101',
        'buses': [_posicion(capturado: ahora, emitido: ahora)],
      },
    ]);
    expect(medidor.resumen.muestrasEmision, 4);

    socket.emitEvent([
      'bus:visible',
      {
        'busId': 'BUS-ABC123',
        'routeId': 'R-101',
        'eventId': 'aviso-1',
        'position': _posicion(capturado: ahora, emitido: ahora),
      },
    ]);
    expect(medidor.resumen.muestrasEmision, 5);
    expect(medidor.resumen.muestrasCaptura, 5);

    // Un aviso sin posición no tiene nada que medir, y un evento roto
    // tampoco tumba nada.
    socket.emitEvent([
      'bus:visible',
      {'busId': 'BUS-ABC123', 'routeId': 'R-101', 'position': null},
    ]);
    socket.emitEvent(['bus:position', 'no soy un mapa']);
    expect(medidor.resumen.muestrasEmision, 5);

    // Lo medido no sale de la app: solo se puede leer aquí dentro.
    expect(medidor.resumen.hayDatos, isTrue);
  });
}
