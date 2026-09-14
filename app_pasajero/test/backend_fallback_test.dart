import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/realtime_providers.dart';

/// Backend mínimo de verdad, escuchando en loopback: `/api/health`,
/// `/api/companies` y un Socket.IO reducido a lo que la app usa (saludo de
/// Engine.IO 4, conexión al espacio `/` y eventos). Apunta qué le pidió la
/// app y por dónde, que es lo que estas pruebas necesitan ver.
///
/// Sin binding de widgets a propósito: el de pruebas cambia el HttpClient
/// por uno que contesta 400 a todo, y aquí se quiere red real.
class _BackendFalso {
  _BackendFalso._(this._server) {
    _server.listen(_atender);
  }

  static Future<_BackendFalso> arrancar() async =>
      _BackendFalso._(await HttpServer.bind(InternetAddress.loopbackIPv4, 0));

  final HttpServer _server;
  final rutasHttp = <String>[];
  final _sockets = <WebSocket>[];

  /// Eventos recibidos por el socket, una lista por conexión.
  final conexiones = <List<List<dynamic>>>[];

  String get url => 'http://127.0.0.1:${_server.port}';

  Future<void> _atender(HttpRequest request) async {
    final path = request.uri.path;
    if (path.startsWith('/ws') &&
        WebSocketTransformer.isUpgradeRequest(request)) {
      final ws = await WebSocketTransformer.upgrade(request);
      final eventos = <List<dynamic>>[];
      _sockets.add(ws);
      conexiones.add(eventos);
      ws.add('0${jsonEncode({
            'sid': 'e${_sockets.length}',
            'upgrades': <String>[],
            'pingInterval': 25000,
            'pingTimeout': 20000,
            'maxPayload': 1000000,
          })}');
      ws.listen((data) {
        if (data is! String) return;
        if (data.startsWith('40')) {
          ws.add('40${jsonEncode({'sid': 's${_sockets.length}'})}');
        } else if (data.startsWith('42')) {
          eventos.add(jsonDecode(data.substring(2)) as List<dynamic>);
        }
      });
      return;
    }
    rutasHttp.add(path);
    request.response.headers.contentType = ContentType.json;
    switch (path) {
      case '/api/health':
        request.response.write('{"status":"ok"}');
      case '/api/companies':
        request.response.write('[]');
      default:
        request.response.statusCode = HttpStatus.notFound;
    }
    await request.response.close();
  }

  /// Corta las conexiones de socket abiertas, como un túnel que parpadea: el
  /// servidor sigue vivo y el cliente tiene que volver solo.
  Future<void> cortarSockets() async {
    for (final ws in _sockets) {
      await ws.close();
    }
  }

  Future<void> cerrar() async {
    await cortarSockets();
    await _server.close(force: true);
  }
}

List<String> _suscripciones(List<List<dynamic>> eventos) => [
      for (final evento in eventos)
        if (evento.first == 'subscribe:route') evento[1] as String,
    ];

Future<void> _esperarA(bool Function() condicion, String que) async {
  final limite = DateTime.now().add(const Duration(seconds: 20));
  while (!condicion()) {
    if (DateTime.now().isAfter(limite)) fail('No pasó a tiempo: $que');
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
}

void main() {
  test(
      'con la principal caída, HTTP y socket van los dos al respaldo, y el '
      'socket vuelve solo con las rutas que seguía', () async {
    // Un puerto que nadie escucha: la principal no contesta.
    final muerto = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final principal = 'http://127.0.0.1:${muerto.port}';
    await muerto.close();

    final respaldo = await _BackendFalso.arrancar();
    addTearDown(respaldo.cerrar);

    // El mismo camino que `main.dart`: el resolver elige y el resultado se
    // inyecta en `backendUrlProvider`.
    final url = await BackendResolver.resolver(
      principal: principal,
      respaldo: respaldo.url,
      tiempoPrincipal: const Duration(seconds: 1),
      tiempoRespaldo: const Duration(seconds: 2),
    );
    expect(url, respaldo.url);

    final container = ProviderContainer(
      overrides: [backendUrlProvider.overrideWith(() => BackendUrl.fija(url))],
    );
    addTearDown(container.dispose);

    final empresas = container.listen(companiesProvider.future, (_, __) {});
    await empresas.read();
    expect(respaldo.rutasHttp, contains('/api/companies'));

    final realtime = container.read(realtimeServiceProvider);
    final estados = <ConnectionStatus>[];
    final sub = realtime.connectionStateStream.listen(estados.add);
    addTearDown(sub.cancel);

    realtime.connect();
    realtime.subscribeToRoute('R-101');
    realtime.subscribeToRoute('R-102');
    realtime.unsubscribeFromRoute('R-102');

    // Si el socket siguiera en la principal, esta conexión no llegaría nunca.
    await _esperarA(
      () =>
          respaldo.conexiones.isNotEmpty &&
          _suscripciones(respaldo.conexiones.first).contains('R-101'),
      'la primera suscripción por el respaldo',
    );

    await respaldo.cortarSockets();
    await _esperarA(
      () =>
          respaldo.conexiones.length >= 2 &&
          _suscripciones(respaldo.conexiones[1]).contains('R-101'),
      'la reconexión con la ruta suscrita',
    );
    // Las suscripciones salen todas juntas al conectar: un margen corto basta
    // para ver que la ruta que se dejó de seguir no vuelve.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(_suscripciones(respaldo.conexiones[1]), ['R-101']);

    expect(estados, contains(ConnectionStatus.disconnected));
    expect(estados.last, ConnectionStatus.connected);
    expect(realtime.isConnected, isTrue);
  });
}
