// El contrato con el backend (T8.5): los eventos de socket que genera
// tests/contrato.test.ts en YaVieneBackend, tal cual, entrando por el
// `RealtimeService` de la app hasta el stream de buses que pinta el mapa.
//
// Los archivos viven en ya_viene_core/test/fixtures/contrato/ (los copia
// tool/sincronizar-contrato.sh). Sin red: el socket es el del paquete, sin
// conectar, y cada evento se le entrega con `emitEvent`, que es por donde
// pasa un paquete que llega del servidor.
//
// El contrato fija las fechas para no cambiar en cada corrida: aquí se
// corren a «ahora» (el pasajero no cree una posición en vivo de hace meses)
// y la captura se adelanta en cada paso, porque dos posiciones con la misma
// captura son el mismo punto y la segunda no mueve el bus. El `eventId` del
// contrato es un marcador fijo; aquí cada aviso lleva el suyo, como en el
// servidor, porque el pasajero no aplica dos veces el mismo.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:ya_viene_core/ya_viene_core.dart';
import 'package:ya_viene_pasajero/features/map/data/services/realtime_service.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/bus_stream.dart';

Map<String, dynamic> _leer(String nombre) => jsonDecode(
      File('../ya_viene_core/test/fixtures/contrato/$nombre.json')
          .readAsStringSync(),
    ) as Map<String, dynamic>;

/// [json] con cada posición fechada ahora y capturada [adelanto] después de
/// lo que dice el contrato.
Object? _deAhora(Object? json, {Duration adelanto = Duration.zero}) =>
    switch (json) {
      Map() => {
          for (final MapEntry(:key, :value) in json.entries)
            key as String: switch (key) {
              'timestamp' => DateTime.now().toUtc().toIso8601String(),
              'capturedAt' => (value as int) + adelanto.inMilliseconds,
              _ => _deAhora(value, adelanto: adelanto),
            },
        },
      List() => [for (final item in json) _deAhora(item, adelanto: adelanto)],
      _ => json,
    };

void main() {
  test('los eventos del contrato llevan el mapa del pasajero de punta a punta',
      () async {
    late io.Socket socket;
    final servicio = RealtimeService(
      'http://127.0.0.1:59131',
      crearSocket: (url, opciones) => socket = io.io(url, <String, dynamic>{
        ...opciones,
        'autoConnect': false,
      }),
    );
    servicio.connect();
    addTearDown(servicio.dispose);

    final fotos = <List<BusPosition>>[];
    final escucha =
        buildRoutePositionsStream(servicio, {'R-101'}).listen(fotos.add);
    addTearDown(escucha.cancel);

    var avisos = 0;
    Future<Map<String, BusPosition>> llega(String evento, String archivo,
        {Duration adelanto = Duration.zero}) async {
      final antes = fotos.length;
      final datos =
          _deAhora(_leer(archivo), adelanto: adelanto) as Map<String, dynamic>;
      if (datos.containsKey('eventId')) datos['eventId'] = 'aviso-${avisos++}';
      socket.emitEvent([evento, datos]);
      // Las posiciones en vivo salen juntas cada 200 ms.
      final hasta = DateTime.now().add(const Duration(seconds: 2));
      while (fotos.length == antes && DateTime.now().isBefore(hasta)) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      expect(fotos.length, greaterThan(antes),
          reason: '$evento no cambió el mapa');
      return {for (final p in fotos.last) p.busId: p};
    }

    // Al suscribirse a la ruta: los dos buses.
    var mapa =
        await llega('positions:batch', 'socket-pasajero-positions-batch');
    expect(mapa.keys, {'BUS-ABC123', 'BUS-DEF456'});
    expect(mapa['BUS-ABC123']!.lat, 10.988);
    expect(mapa['BUS-DEF456']!.lat, 10.989);

    // Una posición en vivo de un bus.
    mapa = await llega('bus:position', 'socket-pasajero-bus-position',
        adelanto: const Duration(seconds: 1));
    expect(mapa['BUS-ABC123']!.lat, 10.9878);
    expect(mapa['BUS-ABC123']!.lon, -74.7889);

    // Varias juntas: el servicio las reparte de una en una.
    mapa = await llega('positions:update', 'socket-pasajero-positions-update',
        adelanto: const Duration(seconds: 2));
    expect(mapa['BUS-ABC123']!.lat, 10.988);
    expect(mapa['BUS-DEF456']!.lat, 10.989);

    // La empresa lo oculta y lo vuelve a mostrar.
    mapa = await llega('bus:hidden', 'socket-pasajero-bus-hidden');
    expect(mapa.keys, {'BUS-DEF456'});
    mapa = await llega('bus:visible', 'socket-pasajero-bus-visible',
        adelanto: const Duration(seconds: 3));
    expect(mapa.keys, {'BUS-ABC123', 'BUS-DEF456'});

    // El equipo se desconecta y la empresa borra el otro bus.
    mapa = await llega('bus:left', 'socket-pasajero-bus-left');
    expect(mapa.keys, {'BUS-DEF456'});
    mapa = await llega('bus:removed', 'socket-pasajero-bus-removed');
    expect(mapa, isEmpty);
  });
}
