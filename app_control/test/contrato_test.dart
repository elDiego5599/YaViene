// El contrato con el backend (T8.5), del lado del panel.
//
// Las respuestas y los eventos de ya_viene_core/test/fixtures/contrato/ los
// genera tests/contrato.test.ts en YaVieneBackend con el servidor de verdad
// (tool/sincronizar-contrato.sh los copia). Aquí entran por el cliente real:
// las respuestas REST por la `Dio` de `AuthApi` y `FleetApi`, con un
// adaptador que contesta el archivo en vez de la red, y los eventos por el
// socket del paquete, sin conectar, con `emitEvent`, que es por donde pasa
// un paquete que llega del servidor.
//
// La regla que más importa (T1.1): el `bus:position` que recibe el panel no
// trae placa, interno ni conductor, así que el panel tiene que conservar los
// que ya tenía. El contrato lo deja escrito en los dos lados.
//
// Las capturas del contrato son todas iguales para que el archivo no cambie
// en cada corrida; aquí se adelantan en cada paso, porque dos posiciones con
// la misma captura son el mismo punto y la segunda no mueve el bus.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:ya_viene_control/features/auth/data/auth_api.dart';
import 'package:ya_viene_control/features/auth/domain/auth_session.dart';
import 'package:ya_viene_control/features/auth/presentation/providers/auth_providers.dart';
import 'package:ya_viene_control/features/fleet/data/fleet_api.dart';
import 'package:ya_viene_control/features/fleet/domain/fleet_bus.dart';
import 'package:ya_viene_control/features/fleet/presentation/providers/fleet_providers.dart';
import 'package:ya_viene_control/features/fleet/presentation/providers/reportes_provider.dart'
    show CeldaBusqueda, RutaBusquedas;
import 'package:ya_viene_core/core/providers/app_providers.dart'
    show BackendUrl, backendUrlProvider;
import 'package:ya_viene_core/ya_viene_core.dart' show MotivoQueja;

const _backend = 'http://127.0.0.1:59141';

Object? _leer(String nombre) => jsonDecode(
  File(
    '../ya_viene_core/test/fixtures/contrato/$nombre.json',
  ).readAsStringSync(),
);

Map<String, dynamic> _mapa(String nombre) =>
    _leer(nombre) as Map<String, dynamic>;

/// Contesta cada pedido con el archivo del contrato que le toca.
class _Contrato implements HttpClientAdapter {
  static const _archivos = {
    'POST /api/admin/login': 'rest-admin-login',
    'POST /api/fleet/renovar': 'rest-panel-renovar',
    'GET /api/fleet/positions': 'rest-fleet-positions',
    'GET /api/fleet/routes': 'rest-fleet-routes',
    'GET /api/panel/busquedas': 'rest-panel-busquedas',
    'GET /api/panel/busquedas/R-101/calor': 'rest-panel-busquedas-calor',
    'GET /api/panel/quejas': 'rest-panel-quejas',
    'POST /api/fleet/buses': 'rest-fleet-bus-created',
    'PATCH /api/fleet/buses/BUS-XYZ987': 'rest-fleet-bus-updated',
    'POST /api/fleet/buses/visibility': 'rest-fleet-visibility-all',
    'POST /api/fleet/buses/BUS-ABC123/visibility': 'rest-fleet-visibility',
  };

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final archivo = _archivos['${options.method} ${options.path}'];
    if (archivo == null) {
      return ResponseBody.fromString('{}', 404, headers: _json);
    }
    return ResponseBody.fromString(
      jsonEncode(_leer(archivo)),
      200,
      headers: _json,
    );
  }

  static const _json = {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  };

  @override
  void close({bool force = false}) {}
}

Dio _dio() =>
    Dio(BaseOptions(baseUrl: _backend))..httpClientAdapter = _Contrato();

/// El evento del contrato con la captura [adelanto] después.
Object? _adelantado(Object? json, Duration adelanto) => switch (json) {
  Map() => {
    for (final MapEntry(:key, :value) in json.entries)
      key as String: key == 'capturedAt' && value is int
          ? value + adelanto.inMilliseconds
          : _adelantado(value, adelanto),
  },
  List() => [for (final item in json) _adelantado(item, adelanto)],
  _ => json,
};

void main() {
  test('POST /api/admin/login se lee como la sesión del panel', () async {
    final sesion = await AuthApi(
      baseUrl: _backend,
      dio: _dio(),
    ).login('u', 'c');
    expect(sesion.token, isNotEmpty);
    expect(sesion.companyId, 'EMP-01');
    expect(sesion.companyName, 'Sobusa');
  });

  test('POST /api/fleet/renovar se lee como la sesión del panel', () async {
    final sesion = await AuthApi(baseUrl: _backend, dio: _dio()).renovar('tok');
    expect(sesion.token, isNotEmpty);
    expect(sesion.companyId, 'EMP-01');
    expect(sesion.companyName, 'Sobusa');
  });

  test('las respuestas de /api/fleet se leen con FleetApi', () async {
    final api = FleetApi(baseUrl: _backend, dio: _dio());

    final buses = await api.fetchPositions('tok');
    expect(buses.map((b) => b.busId), ['BUS-ABC123', 'BUS-DEF456']);
    for (final bus in buses) {
      expect(bus.companyId, 'EMP-01');
      expect(bus.placa, isNotEmpty);
      expect(bus.interno, isNotEmpty);
      expect(bus.routeId, 'R-101');
      expect(bus.visible, isTrue);
      expect(bus.online, isTrue);
      expect(bus.lat, isNotNull);
      expect(bus.lon, isNotNull);
      expect(bus.capturedAt, isNotNull);
    }

    final rutas = await api.fetchRoutes('tok');
    expect(rutas, hasLength(6));
    expect(rutas.first.routeId, 'R-101');
    expect(rutas.first.name, 'B18 Tcherassi');
    expect(rutas.first.total, 2);
    expect(rutas.first.online, 2);

    final reportes = await api.fetchSearchReports(
      'tok',
      desde: DateTime.utc(2000),
      hasta: DateTime.utc(2100),
    );
    final rutasBusquedas = (reportes['rutas'] as List)
        .map(
          (item) =>
              RutaBusquedas.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
    expect(rutasBusquedas, hasLength(6));
    final rutaConBusquedas = rutasBusquedas.singleWhere(
      (ruta) => ruta.id == 'R-101',
    );
    expect(rutaConBusquedas.nombre, 'B18 Tcherassi');
    expect(rutaConBusquedas.total, 5);
    expect(rutaConBusquedas.porHora, hasLength(24));
    final maximoPorHora = rutaConBusquedas.porHora.reduce(
      (a, b) => a > b ? a : b,
    );
    expect(rutaConBusquedas.porHora[rutaConBusquedas.horaPico!], maximoPorHora);
    final rutasSinBusquedas = rutasBusquedas
        .where((ruta) => ruta.total == 0)
        .toList();
    expect(rutasSinBusquedas, isNotEmpty);
    expect(
      rutasSinBusquedas.map((ruta) => ruta.horaPico),
      everyElement(isNull),
    );

    final calor = await api.fetchSearchHeatmap(
      'tok',
      routeId: 'R-101',
      desde: DateTime.utc(2000),
      hasta: DateTime.utc(2100),
    );
    final celdas = (calor['celdas'] as List)
        .map(
          (item) =>
              CeldaBusqueda.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
    expect(celdas, hasLength(1));
    expect(celdas.single.count, 5);
    expect(celdas.single.lat, 10.99035);
    expect(celdas.single.lng, -74.78967);

    // La queja del contrato: con su celda de 150 m, su bus y su hora en
    // milisegundos, sin placa (D18).
    final quejas = await api.fetchQuejas(
      'tok',
      desde: DateTime.utc(2000),
      hasta: DateTime.utc(2100),
    );
    final queja = quejas.quejas.single;
    expect(queja.id, '<quejaId>');
    expect(queja.motivo, MotivoQueja.noParo);
    expect(queja.texto, 'No paró en el paradero');
    expect(queja.routeId, 'R-101');
    expect(queja.ruta, 'B18 Tcherassi');
    expect(queja.busId, 'BUS-ABC123');
    expect(queja.celda, (lat: 10.99035, lng: -74.78967));
    expect(queja.hora, DateTime.utc(2026));
    expect(queja.creado, DateTime.utc(2026));
    expect(quejas.celdas.single.total, 1);
    expect(quejas.celdas.single.lat, 10.99035);
    expect(quejas.celdas.single.lng, -74.78967);

    final creado = await api.createBus(
      'tok',
      placa: 'XYZ987',
      routeId: 'R-102',
    );
    expect(creado.busId, 'BUS-XYZ987');
    expect(creado.placa, 'XYZ987');
    expect(creado.interno, isNotEmpty);
    expect(creado.routeId, 'R-102');
    expect(creado.visible, isFalse);
    expect(creado.lat, isNull);

    final editado = await api.updateBus('tok', 'BUS-XYZ987', interno: '77');
    expect(editado.interno, '77');
    expect(editado.placa, 'XYZ987');

    expect(await api.setAllVisibility('tok', true), 2);
    final oculto = await api.setVisibility('tok', 'BUS-ABC123', false);
    expect(oculto.busId, 'BUS-ABC123');
    expect(oculto.visible, isFalse);
  });

  test(
    'los eventos del contrato llevan la flota del panel de punta a punta',
    () async {
      late io.Socket socket;
      final container = ProviderContainer(
        overrides: [
          backendUrlProvider.overrideWith(() => BackendUrl.fija(_backend)),
          fleetProvider.overrideWith(
            (ref) => FleetNotifier(
              ref,
              api: FleetApi(baseUrl: _backend, dio: _dio()),
              resincronizarCada: const Duration(hours: 1),
            ),
          ),
          fleetIoSocketFactoryProvider.overrideWithValue(
            (url, opciones) => socket = io.io(url, <String, dynamic>{
              ...opciones,
              'autoConnect': false,
            }),
          ),
        ],
      );
      addTearDown(container.dispose);
      container.read(authProvider.notifier).state = const AuthState(
        status: AuthStatus.authenticated,
        session: AuthSession(
          token: 'tok',
          companyId: 'EMP-01',
          companyName: 'Sobusa',
        ),
      );
      final notifier = container.read(fleetProvider.notifier);

      // Al entrar, la flota llega por REST.
      notifier.start();
      final hasta = DateTime.now().add(const Duration(seconds: 2));
      while (notifier.state.buses.length < 2 &&
          DateTime.now().isBefore(hasta)) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(notifier.state.buses.keys, {'BUS-ABC123', 'BUS-DEF456'});

      Future<Map<String, FleetBus>> llega(
        String evento,
        String archivo, {
        Duration adelanto = Duration.zero,
      }) async {
        socket.emitEvent([evento, _adelantado(_leer(archivo), adelanto)]);
        await Future<void>.delayed(Duration.zero);
        return notifier.state.buses;
      }

      var flota = await llega('fleet:batch', 'socket-panel-fleet-batch');
      expect(flota['BUS-ABC123']!.placa, 'ABC123');
      expect(flota['BUS-ABC123']!.lat, 10.988);

      // La posición en vivo no trae placa: el bus se mueve y la conserva.
      expect(_mapa('socket-panel-bus-position').containsKey('placa'), isFalse);
      flota = await llega(
        'bus:position',
        'socket-panel-bus-position',
        adelanto: const Duration(seconds: 1),
      );
      final movido = flota['BUS-ABC123']!;
      expect(movido.lat, 10.9878);
      expect(movido.lon, -74.7889);
      expect(movido.placa, 'ABC123');
      expect(movido.interno, '001');
      expect(movido.online, isTrue);
      expect(movido.visible, isTrue);

      // La empresa lo oculta y lo vuelve a mostrar, con y sin posición.
      flota = await llega('bus:hidden', 'socket-panel-bus-hidden');
      expect(flota['BUS-ABC123']!.visible, isFalse);
      flota = await llega(
        'bus:visible',
        'socket-panel-bus-visible-sin-posicion',
      );
      expect(flota['BUS-ABC123']!.visible, isTrue);
      expect(flota['BUS-ABC123']!.lat, 10.9878);
      flota = await llega('bus:hidden', 'socket-panel-bus-hidden');
      flota = await llega(
        'bus:visible',
        'socket-panel-bus-visible',
        adelanto: const Duration(seconds: 2),
      );
      expect(flota['BUS-ABC123']!.visible, isTrue);
      expect(flota['BUS-ABC123']!.lat, 10.988);
      expect(flota['BUS-ABC123']!.placa, 'ABC123');

      // El equipo se desconecta: sigue en la lista, sin posición.
      flota = await llega('bus:left', 'socket-panel-bus-left');
      expect(flota['BUS-ABC123']!.online, isFalse);
      expect(flota['BUS-ABC123']!.lat, isNull);
      expect(flota['BUS-ABC123']!.placa, 'ABC123');

      // Lo borran en otro panel: sale de este.
      flota = await llega('bus:removed', 'socket-panel-bus-removed');
      expect(flota.keys, {'BUS-ABC123'});
    },
  );
}
