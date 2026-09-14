// Pruebas de cambiar de backend con la app abierta.
//
// Lo que se protege: si el túnel de siempre se cae con el pasajero mirando el
// mapa, la app tiene que pasar sola al respaldo, con las mismas rutas y sin
// reiniciar; y una vez allí no debe ir y volver cada vez que algo parpadea.
//
// Van con `testWidgets` por el reloj de mentira: los 30 s del supervisor y
// las esperas de las sondas pasan con `pump`, sin esperarlos de verdad. Por
// eso tampoco hay red real: los sockets son de mentira y una `_Red` decide
// qué backend contesta.
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socket_io_client/socket_io_client.dart' as sio;
import 'package:ya_viene_core/ya_viene_core.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/realtime_providers.dart';

const principal = 'https://tunel.ngrok-free.dev';
const respaldo = 'https://ya-viene-backend.fly.dev';

/// Lo que tarda el respaldo en contestar cuando está dormido: los 8 s medidos
/// que cuenta `BackendResolver.esperaRespaldo`.
const arranqueEnFrio = Duration(seconds: 8);

/// Los `onReconnect*` del paquete se cuelgan del `Manager` del socket, no del
/// socket. Uno de verdad que no conecta basta para eso: en estas pruebas
/// nadie dispara esos eventos.
final _gestor = sio.io('http://127.0.0.1:1', <String, dynamic>{
  'autoConnect': false,
  'forceNew': true,
}).io;

/// Qué backends contestan, y los sockets que la app abrió contra ellos.
class _Red {
  _Red(Iterable<String> vivas) : vivas = vivas.toSet();

  final Set<String> vivas;
  final sockets = <_SocketFalso>[];
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

  List<String> get suscripciones => [
        for (final evento in emitidos)
          if (evento.first == 'subscribe:route') evento[1]! as String,
      ];

  @override
  void on(String event, handler) => (_oyentes[event] ??= []).add(handler);

  @override
  void emit(String event, [dynamic data]) => emitidos.add([event, data]);

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

/// La app recién abierta sobre la principal, que es lo que elige el arranque
/// cuando la principal contesta.
ProviderContainer _app(_Red red) => ProviderContainer(overrides: [
      backendUrlProvider.overrideWith(() => BackendUrl(
            principal,
            principal: principal,
            respaldo: respaldo,
            sonda: red.sonda,
          )),
      realtimeSocketFactoryProvider.overrideWithValue(red.crearSocket),
    ]);

/// Cierra la app y deja correr lo que quedara en vuelo, para que ningún
/// temporizador siga vivo al terminar la prueba.
Future<void> _cerrar(WidgetTester tester, ProviderContainer app) async {
  app.dispose();
  await tester.pump(const Duration(minutes: 1));
}

void main() {
  testWidgets(
      'el primario cae después de conectar → en ≤ 45 s está en el respaldo y '
      'resuscrito', (tester) async {
    final red = _Red({principal, respaldo});
    final app = _app(red);
    final realtime = app.read(realtimeServiceProvider)..connect();
    realtime.subscribeToRoute('R-101');
    await tester.pump();
    expect(realtime.isConnected, isTrue);

    red.tumbar(principal);
    // Antes de 30 s sin conexión no se mueve: podría ser un parpadeo.
    await tester.pump(const Duration(seconds: 29));
    expect(app.read(backendUrlProvider), principal);
    expect(red.sockets, hasLength(1));

    await tester.pump(const Duration(seconds: 16));
    expect(app.read(backendUrlProvider), respaldo);
    final vivo = red.abiertos.single;
    expect(vivo.url, respaldo);
    expect(vivo.connected, isTrue);
    expect(vivo.suscripciones, ['R-101']);
    expect(realtime.isConnected, isTrue);

    await _cerrar(tester, app);
  });

  testWidgets('el primario vuelve → no se regresa hasta reiniciar',
      (tester) async {
    final red = _Red({principal, respaldo});
    final app = _app(red);
    final realtime = app.read(realtimeServiceProvider)..connect();
    await tester.pump();
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
    expect(app.read(backendUrlProvider), respaldo);
    expect(red.sockets, hasLength(2));
    expect(red.abiertos.single.url, respaldo);
    expect(realtime.isConnected, isTrue);

    await _cerrar(tester, app);
  });

  testWidgets(
      'los dos caídos → sigue reintentando sin crear sockets en bucle',
      (tester) async {
    final red = _Red({principal, respaldo});
    final app = _app(red);
    final realtime = app.read(realtimeServiceProvider)..connect();
    await tester.pump();

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
    expect(app.read(backendUrlProvider), principal);

    red.revivir(principal);
    await tester.pump();
    expect(realtime.isConnected, isTrue);
    expect(red.sockets, hasLength(1));

    await _cerrar(tester, app);
  });

  testWidgets('cambiar de URL no pierde las rutas suscritas', (tester) async {
    final red = _Red({principal, respaldo});
    final app = _app(red);
    final realtime = app.read(realtimeServiceProvider)..connect();
    realtime
      ..subscribeToRoute('R-101')
      ..subscribeToRoute('R-202')
      ..subscribeToRoute('R-303')
      ..unsubscribeFromRoute('R-303');
    // El mapa ya escucha antes del cambio y no vuelve a suscribirse después.
    final posiciones = <Map<String, dynamic>>[];
    final escucha = realtime.busPositionStream.listen(posiciones.add);
    await tester.pump();

    red.tumbar(principal);
    final cambio = app.read(backendUrlProvider.notifier).reResolver();
    await tester.pump(const Duration(seconds: 11));
    await cambio;

    expect(app.read(realtimeServiceProvider), same(realtime));
    final nuevo = red.abiertos.single;
    expect(nuevo.url, respaldo);
    expect(nuevo.suscripciones, ['R-101', 'R-202']);

    nuevo.recibir('bus:position', {'busId': 'B-7', 'routeId': 'R-101'});
    await tester.pump();
    expect(posiciones, [
      {'busId': 'B-7', 'routeId': 'R-101'},
    ]);

    // Sin `await`: `cancel` devuelve un futuro de la zona raíz, y esperarlo
    // saca a la prueba del reloj de mentira; el `pump` de después ya no
    // vuelve nunca.
    unawaited(escucha.cancel());
    await _cerrar(tester, app);
  });
}
