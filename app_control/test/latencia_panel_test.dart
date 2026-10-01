// T7.6: el panel apunta cuánto tardó en llegarle cada posición.
//
// Los eventos entran por el socket de verdad del paquete, sin conectar, con
// `emitEvent`, que es por donde pasa un paquete que llega del servidor.
import 'package:flutter_test/flutter_test.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:ya_viene_control/features/fleet/data/fleet_socket_service.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

Map<String, dynamic> _bus({
  required int capturado,
  required int emitido,
  String busId = 'BUS-ABC123',
}) => {
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
  'visible': true,
  'online': true,
};

void main() {
  test('cada bus que llega por el socket deja su muestra de latencia', () {
    final medidor = MedidorLatencia();
    late io.Socket socket;
    final servicio = FleetSocketService(
      baseUrl: 'http://127.0.0.1:59151',
      token: 'tok',
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
      'fleet:batch',
      {
        'companyId': 'EMP-01',
        'buses': [
          _bus(capturado: ahora - 900, emitido: ahora - 100),
          _bus(
            capturado: ahora - 800,
            emitido: ahora - 50,
            busId: 'BUS-DEF456',
          ),
        ],
      },
    ]);
    expect(medidor.resumen.muestrasEmision, 2);

    socket.emitEvent(['bus:position', _bus(capturado: ahora, emitido: ahora)]);
    expect(medidor.resumen.muestrasEmision, 3);

    socket.emitEvent([
      'bus:visible',
      {
        'busId': 'BUS-ABC123',
        'routeId': 'R-101',
        'eventId': 'aviso-1',
        'position': _bus(capturado: ahora, emitido: ahora),
      },
    ]);
    expect(medidor.resumen.muestrasEmision, 4);
    expect(medidor.resumen.muestrasCaptura, 4);

    // Un aviso sin posición no tiene nada que medir.
    socket.emitEvent([
      'bus:visible',
      {
        'busId': 'BUS-ABC123',
        'routeId': 'R-101',
        'eventId': 'aviso-2',
        'position': null,
      },
    ]);
    expect(medidor.resumen.muestrasEmision, 4);
  });
}
