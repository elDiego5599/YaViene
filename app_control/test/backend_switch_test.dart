// Pruebas de cambiar de backend con el panel abierto.
//
// Lo que se protege: si el túnel de siempre se cae con el operador mirando la
// flota, el panel tiene que pasar solo al respaldo sin cerrar la sesión ni
// perder la ruta y el bus que tenía elegidos; y si allí el token no vale, tiene
// que mandarlo a iniciar sesión con el aviso de siempre, no dejarlo con un
// error genérico.
//
// Van con `testWidgets` por el reloj de mentira: los 30 s del supervisor y las
// esperas de las sondas pasan con `pump`, sin esperarlos de verdad. Por eso
// tampoco hay red real: los sockets y la API son de mentira y una `_Red`
// decide qué backend contesta.
import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socket_io_client/socket_io_client.dart' as sio;
import 'package:ya_viene_control/features/auth/domain/auth_session.dart';
import 'package:ya_viene_control/features/auth/presentation/providers/auth_providers.dart';
import 'package:ya_viene_control/features/fleet/data/fleet_api.dart';
import 'package:ya_viene_control/features/fleet/domain/fleet_bus.dart';
import 'package:ya_viene_control/features/fleet/domain/fleet_route.dart';
import 'package:ya_viene_control/features/fleet/presentation/providers/fleet_providers.dart';
import 'package:ya_viene_core/core/providers/app_providers.dart'
    show BackendUrl, backendUrlProvider;

const principal = 'https://tunel.ngrok-free.dev';
const respaldo = 'https://ya-viene-backend.fly.dev';

/// Lo que tarda el respaldo en contestar cuando está dormido: los 8 s medidos
/// que cuenta `BackendResolver.esperaRespaldo`.
const arranqueEnFrio = Duration(seconds: 8);

const _sesion = AuthSession(
  token: 'tok',
  companyId: 'c-1',
  companyName: 'Empresa 1',
);

/// La flota que devuelven los dos backends: es la misma empresa vista desde
/// dos sitios. R-1 es la única ruta con buses reportando, así que el panel
/// abre en ella.
const _flota = [
  FleetBus(
    busId: 'B-1',
    companyId: 'c-1',
    routeId: 'R-2',
    placa: 'ABC123',
    visible: true,
    online: false,
  ),
  FleetBus(
    busId: 'B-2',
    companyId: 'c-1',
    routeId: 'R-1',
    placa: 'DEF456',
    visible: true,
    online: true,
  ),
];
const _rutas = [
  FleetRoute(routeId: 'R-1', name: 'Ruta 1', total: 1, online: 1),
  FleetRoute(routeId: 'R-2', name: 'Ruta 2', total: 1, online: 0),
];

/// Los `onReconnect*` del paquete se cuelgan del `Manager` del socket, no del
/// socket. Uno de verdad que no conecta basta para eso: en estas pruebas
/// nadie dispara esos eventos.
final _gestor = sio.io('http://127.0.0.1:1', <String, dynamic>{
  'autoConnect': false,
  'forceNew': true,
}).io;

/// Qué backends contestan, en cuáles vale el token de la sesión, y lo que el
/// panel les pidió.
class _Red {
  _Red(Iterable<String> vivas) : vivas = vivas.toSet();

  final Set<String> vivas;

  /// Backends que no reconocen el token: el respaldo tiene su propia base, y
  /// una sesión abierta en el túnel no tiene por qué existir allí.
  final rechazanToken = <String>{};
  final sockets = <_SocketFalso>[];

  /// A qué backend fue cada pedido de la flota por REST.
  final pedidos = <String>[];
  var sondeos = 0;

  List<_SocketFalso> get abiertos => [
    for (final socket in sockets)
      if (!socket.cerrado) socket,
  ];

  _SocketFalso crearSocket(String url, Map<String, dynamic> opciones) {
    final socket = _SocketFalso(url, this);
    sockets.add(socket);
    // `autoConnect`: intenta en cuanto el servicio termina de colgar sus
    // oyentes, como el de verdad.
    scheduleMicrotask(socket.connect);
    return socket;
  }

  /// La sonda de `BackendResolver` con sus tiempos de verdad: la que no
  /// contesta agota su espera y el respaldo tarda lo del arranque en frío.
  Future<bool> sonda(String url, Duration espera) async {
    sondeos++;
    final viva = vivas.contains(url);
    await Future<void>.delayed(
      !viva ? espera : (url == respaldo ? arranqueEnFrio : Duration.zero),
    );
    return viva;
  }

  /// Lo que hace el backend con un pedido REST: si no contesta, el error de
  /// red de Dio; si no reconoce el token, el 401 que `FleetApi` convierte en
  /// [SessionExpiredException].
  void atender(String url, String path) {
    if (!vivas.contains(url)) {
      throw DioException(
        requestOptions: RequestOptions(baseUrl: url, path: path),
        type: DioExceptionType.connectionError,
      );
    }
    if (rechazanToken.contains(url)) throw const SessionExpiredException();
  }

  void tumbar(String url) {
    vivas.remove(url);
    for (final socket in abiertos) {
      if (socket.url == url) socket.caer();
    }
  }

  /// Los sockets abiertos contra [url] vuelven solos, como con la
  /// reconexión del paquete.
  void revivir(String url) {
    vivas.add(url);
    for (final socket in abiertos) {
      if (socket.url == url) socket.connect();
    }
  }
}

class _SocketFalso extends Fake implements sio.Socket {
  _SocketFalso(this.url, this._red);

  final String url;
  final _Red _red;
  final _oyentes = <String, List<dynamic Function(dynamic)>>{};
  final emitidos = <List<Object?>>[];
  var intentos = 0;
  var cerrado = false;

  @override
  bool connected = false;

  /// `socket.io` (el `Manager`) no se declara porque su tipo no se exporta:
  /// cae aquí, como todo lo que el servicio no usa.
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      invocation.memberName == #io ? _gestor : super.noSuchMethod(invocation);

  bool get suscritoAFlota =>
      emitidos.any((evento) => evento.first == 'subscribe:fleet');

  @override
  dynamic Function() on(String event, handler) {
    (_oyentes[event] ??= []).add(handler);
    return () => _oyentes[event]?.remove(handler);
  }

  /// Como el backend (`socket/handler.ts`): quien pide la flota con un token
  /// que allí no vale queda desconectado por el servidor.
  @override
  void emit(String event, [dynamic data]) {
    emitidos.add([event, data]);
    if (event == 'subscribe:fleet' && _red.rechazanToken.contains(url)) {
      connected = false;
      _disparar('disconnect', 'io server disconnect');
    }
  }

  @override
  sio.Socket connect() {
    intentos++;
    if (cerrado || connected) return this;
    if (_red.vivas.contains(url)) {
      connected = true;
      _disparar('connect');
    } else {
      _disparar('connect_error', 'no contesta');
    }
    return this;
  }

  /// Como el de verdad: si estaba conectado, avisa a sus oyentes.
  @override
  sio.Socket disconnect() {
    if (connected) {
      connected = false;
      _disparar('disconnect', 'io client disconnect');
    }
    return this;
  }

  @override
  void dispose() {
    disconnect();
    _oyentes.clear();
    cerrado = true;
  }

  /// El backend se cae con el socket conectado.
  void caer() {
    if (!connected) return;
    connected = false;
    _disparar('disconnect', 'transport close');
  }

  /// Un evento que manda el servidor.
  void recibir(String event, Object? data) => _disparar(event, data);

  void _disparar(String event, [Object? data]) {
    for (final oyente in [...?_oyentes[event]]) {
      oyente(data);
    }
  }
}

/// La API de la flota contra el backend de su `baseUrl`, atendida por la
/// `_Red`.
class _ApiFalsa extends FleetApi {
  _ApiFalsa(String url, this._red) : super(baseUrl: url);

  final _Red _red;

  @override
  Future<List<FleetBus>> fetchPositions(String token) async {
    _red
      ..pedidos.add(baseUrl)
      ..atender(baseUrl, '/api/fleet/positions');
    return _flota;
  }

  @override
  Future<List<FleetRoute>> fetchRoutes(String token) async {
    _red.atender(baseUrl, '/api/fleet/routes');
    return _rutas;
  }
}

/// El panel recién abierto sobre la principal y con la sesión iniciada, que
/// es lo que deja el arranque cuando la principal contesta.
Future<(ProviderContainer, FleetNotifier)> _abrir(
  WidgetTester tester,
  _Red red,
) async {
  final panel = ProviderContainer(
    overrides: [
      backendUrlProvider.overrideWith(
        () => BackendUrl(
          principal,
          principal: principal,
          respaldo: respaldo,
          sonda: red.sonda,
        ),
      ),
      fleetIoSocketFactoryProvider.overrideWithValue(red.crearSocket),
      fleetApiProvider.overrideWith(
        (ref) => _ApiFalsa(ref.watch(backendUrlProvider), red),
      ),
    ],
  );
  panel.read(authProvider.notifier).state = const AuthState(
    status: AuthStatus.authenticated,
    session: _sesion,
  );
  final flota = panel.read(fleetProvider.notifier)..start();
  await tester.pump();
  return (panel, flota);
}

/// Cierra el panel y deja correr lo que quedara en vuelo, para que ningún
/// temporizador siga vivo al terminar la prueba.
Future<void> _cerrar(WidgetTester tester, ProviderContainer panel) async {
  panel.dispose();
  await tester.pump(const Duration(minutes: 1));
}

/// Lo que manda el backend en `bus:position` al panel: la posición, sin
/// placa, interno ni conductor.
Map<String, Object?> _posicion(String busId, {required int sequence}) => {
  'busId': busId,
  'companyId': 'c-1',
  'routeId': 'R-2',
  'lat': 10.98,
  'lon': -74.8,
  'heading': 90,
  'speedKmh': 20,
  'capturedAt': 1000 + sequence,
  'receivedAt': 1000 + sequence,
  'sequence': sequence,
  'isGhost': false,
};

void main() {
  testWidgets(
    'el túnel cae con el panel abierto → en ≤ 45 s la flota está en el '
    'respaldo, resuscrita y recargada',
    (tester) async {
      final red = _Red({principal, respaldo});
      final (panel, _) = await _abrir(tester, red);
      expect(panel.read(fleetProvider).connection, FleetConnection.connected);
      expect(red.pedidos, [principal]);

      red.tumbar(principal);
      // Antes de 30 s sin conexión no se mueve: podría ser un parpadeo.
      await tester.pump(const Duration(seconds: 29));
      expect(panel.read(backendUrlProvider), principal);
      expect(red.sockets, hasLength(1));

      await tester.pump(const Duration(seconds: 16));
      expect(panel.read(backendUrlProvider), respaldo);
      final vivo = red.abiertos.single;
      expect(vivo.url, respaldo);
      expect(vivo.connected, isTrue);
      expect(vivo.suscritoAFlota, isTrue);
      expect(red.pedidos, [principal, respaldo]);
      final estado = panel.read(fleetProvider);
      expect(estado.connection, FleetConnection.connected);
      expect(estado.error, isNull);

      await _cerrar(tester, panel);
    },
  );

  testWidgets('el túnel vuelve → el panel no se regresa hasta reiniciar', (
    tester,
  ) async {
    final red = _Red({principal, respaldo});
    final (panel, _) = await _abrir(tester, red);
    red.tumbar(principal);
    await tester.pump(const Duration(seconds: 45));
    expect(red.abiertos.single.url, respaldo);

    red.revivir(principal);
    // Un corte del respaldo más corto que la paciencia tampoco lo mueve.
    red.tumbar(respaldo);
    await tester.pump(const Duration(seconds: 20));
    red.revivir(respaldo);
    await tester.pump(const Duration(minutes: 10));

    // Volver a la principal queda para el próximo arranque en frío, que
    // pregunta otra vez (`main.dart`).
    expect(panel.read(backendUrlProvider), respaldo);
    expect(red.sockets, hasLength(2));
    expect(red.abiertos.single.url, respaldo);
    expect(panel.read(fleetProvider).connection, FleetConnection.connected);

    await _cerrar(tester, panel);
  });

  testWidgets(
    'los dos caídos → sigue reintentando sin abrir sockets en bucle',
    (tester) async {
      final red = _Red({principal, respaldo});
      final (panel, _) = await _abrir(tester, red);

      red
        ..tumbar(principal)
        ..tumbar(respaldo);
      for (var segundo = 0; segundo < 600; segundo++) {
        await tester.pump(const Duration(seconds: 1));
        expect(red.abiertos.length, lessThanOrEqualTo(1));
      }

      // Con los dos caídos la elección da la principal, que es la que ya tiene:
      // ningún socket nuevo, el mismo reintentando cada 15 s, y la pregunta
      // repitiéndose sin amontonarse.
      expect(red.sockets, hasLength(1));
      expect(red.sockets.single.intentos, greaterThanOrEqualTo(30));
      expect(red.sondeos, inInclusiveRange(10, 40));
      expect(panel.read(backendUrlProvider), principal);

      red.revivir(principal);
      await tester.pump();
      expect(panel.read(fleetProvider).connection, FleetConnection.connected);
      expect(red.sockets, hasLength(1));

      await _cerrar(tester, panel);
    },
  );

  testWidgets(
    'cambiar de backend no cierra la sesión ni pierde la ruta y el bus '
    'elegidos',
    (tester) async {
      final red = _Red({principal, respaldo});
      final (panel, flota) = await _abrir(tester, red);
      // El panel abrió en R-1, la ruta con buses andando; el operador se pasó
      // a R-2 y eligió un bus.
      expect(panel.read(fleetProvider).routeFilter, 'R-1');
      flota
        ..setRouteFilter('R-2')
        ..selectBus('B-1');

      red.tumbar(principal);
      final cambio = panel.read(backendUrlProvider.notifier).reResolver();
      await tester.pump(const Duration(seconds: 11));
      await cambio;
      await tester.pump();

      expect(panel.read(backendUrlProvider), respaldo);
      expect(panel.read(fleetProvider.notifier), same(flota));
      final auth = panel.read(authProvider);
      expect(auth.status, AuthStatus.authenticated);
      expect(auth.session?.token, 'tok');
      // Si hay que volver a entrar, el login también va al respaldo.
      expect(panel.read(authProvider.notifier).api.baseUrl, respaldo);
      final estado = panel.read(fleetProvider);
      expect(estado.routeFilter, 'R-2');
      expect(estado.selectedBusId, 'B-1');

      // El bus elegido sigue llegando en vivo, ahora por el socket del
      // respaldo, sin perder lo que el REST sabía de él.
      red.abiertos.single.recibir(
        'bus:position',
        _posicion('B-1', sequence: 9),
      );
      await tester.pump();
      final bus = panel.read(fleetProvider).selectedBus!;
      expect(bus.sequence, 9);
      expect(bus.online, isTrue);
      expect(bus.placa, 'ABC123');

      await _cerrar(tester, panel);
    },
  );

  testWidgets(
    '401 en el respaldo → «Sesión expirada», que lleva al login, y no un '
    'error genérico',
    (tester) async {
      final red = _Red({principal, respaldo})..rechazanToken.add(respaldo);
      final (panel, _) = await _abrir(tester, red);

      red.tumbar(principal);
      await tester.pump(const Duration(seconds: 45));

      expect(panel.read(backendUrlProvider), respaldo);
      final estado = panel.read(fleetProvider);
      // Es la bandera con la que el dashboard avisa «Tu sesión expiró» y manda
      // a iniciar sesión (`dashboard_screen.dart`); ese login va al respaldo.
      expect(estado.sessionExpired, isTrue);
      expect(estado.error, isNull);
      expect(estado.connection, FleetConnection.disconnected);
      expect(panel.read(authProvider.notifier).api.baseUrl, respaldo);
      // Ningún socket queda reintentando con una sesión que ya no vale.
      expect(red.abiertos, isEmpty);

      // Y nada sigue vigilando la conexión: no se vuelve a preguntar.
      final sondeos = red.sondeos;
      await tester.pump(const Duration(minutes: 10));
      expect(red.sondeos, sondeos);
      expect(red.sockets, hasLength(2));

      await _cerrar(tester, panel);
    },
  );

  // T2.11. Un reinicio del backend dura menos que la paciencia del
  // supervisor: el panel se queda donde estaba, el mismo socket vuelve con la
  // reconexión del paquete y tiene que pedir la flota otra vez él solo,
  // porque el backend recién arrancado no sabe quién seguía qué.
  testWidgets(
    'el backend se reinicia → el mismo socket vuelve, pide la flota otra vez '
    'y le llega el lote',
    (tester) async {
      final red = _Red({principal, respaldo});
      final (panel, _) = await _abrir(tester, red);
      final socket = red.abiertos.single;
      expect(socket.suscritoAFlota, isTrue);
      socket.emitidos.clear();

      red.tumbar(principal);
      await tester.pump(const Duration(seconds: 5));
      expect(
        panel.read(fleetProvider).connection,
        FleetConnection.disconnected,
      );
      red.revivir(principal);
      await tester.pump();

      expect(panel.read(fleetProvider).connection, FleetConnection.connected);
      expect(red.sockets, [socket]);
      expect(socket.suscritoAFlota, isTrue);
      expect(panel.read(backendUrlProvider), principal);

      // Lo que contesta el backend a `subscribe:fleet` (`socket/handler.ts`).
      socket.recibir('fleet:batch', {
        'buses': [
          {
            ..._posicion('B-1', sequence: 9),
            'placa': 'ABC123',
            'visible': true,
          },
        ],
      });
      await tester.pump();
      expect(panel.read(fleetProvider).buses['B-1']?.sequence, 9);

      await _cerrar(tester, panel);
    },
  );
}
