import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:ya_viene_core/ya_viene_core.dart';

import '../../../../config.dart';
import '../../domain/repositories/realtime_repository.dart';

/// Cómo se abre un socket. La app usa el de `socket_io_client`; las pruebas
/// ponen uno de mentira.
typedef RealtimeSocketFactory = io.Socket Function(
  String url,
  Map<String, dynamic> opciones,
);

class RealtimeService implements RealtimeRepository {
  /// A qué backend se conecta el socket.
  ///
  /// Antes esto leía `AppConfig.backendUrl` directamente, es decir la
  /// constante de compilación, y se saltaba entero al `BackendResolver` del
  /// arranque: si el túnel de siempre no contestaba, la app se iba al
  /// respaldo para todo lo que va por HTTP —empresas, rutas, posiciones
  /// iniciales— y el socket seguía llamando al túnel caído. La pantalla
  /// quedaba con los datos puestos y «Sin conexión» encima, que es la peor
  /// versión posible: parece que la app funciona a medias.
  ///
  /// La URL puede cambiar después con [cambiarBackend]. [supervisor] se
  /// entera de cada pérdida y recuperación de la conexión, que es lo que usa
  /// para decidir si hay que buscar otro backend.
  RealtimeService(
    this._backendUrl, {
    BackendSupervisor? supervisor,
    RealtimeSocketFactory crearSocket = io.io,
    MedidorLatencia? medidor,
  })  : _supervisor = supervisor,
        _crearSocket = crearSocket,
        _medidor = medidor ?? MedidorLatencia.compartido;

  String _backendUrl;
  final BackendSupervisor? _supervisor;
  final RealtimeSocketFactory _crearSocket;

  /// Apunta cuánto tardó en llegar cada posición (T7.6). Se queda en la
  /// memoria del teléfono: no se manda a ninguna parte.
  final MedidorLatencia _medidor;

  io.Socket? _socket;

  /// Donde se abre, reconecta y suelta el socket: se traga el doble cierre
  /// del paquete cuando el backend corta (`zona_socket.dart`).
  final _zona = zonaSocket();
  final _subscriptions = <String>{};
  final _connectionStateController =
      StreamController<ConnectionStatus>.broadcast();
  final _busPositionController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _batchPositionController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _busLeftController = StreamController<Map<String, dynamic>>.broadcast();
  final _busHiddenController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _busVisibleController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _busRemovedController =
      StreamController<Map<String, dynamic>>.broadcast();
  bool _disposed = false;

  /// Si la app quiere estar conectada: entre [connect] y [disconnect]. Fuera
  /// de ese tramo, un socket cerrado es lo esperado y no una caída.
  bool _quiereConexion = false;
  Timer? _retryTimer;
  ConnectionStatus? _lastConnectionState;

  /// Emite solo si el servicio sigue vivo: eventos tardíos del socket
  /// después de un [dispose] no deben lanzar "Cannot add events".
  void _emit<T>(StreamController<T> controller, T value) {
    if (!_disposed && !controller.isClosed) controller.add(value);
  }

  void _emitConnectionStatus(ConnectionStatus status) {
    _lastConnectionState = status;
    _emit(_connectionStateController, status);
    if (status == ConnectionStatus.connected) {
      _supervisor?.conexionRecuperada();
    } else if (_quiereConexion) {
      _supervisor?.conexionPerdida();
    }
  }

  // Los dos `onReconnect*` se cuelgan del `Manager` del socket, no del
  // socket, y el `dispose` del socket no los suelta. Son métodos y no
  // funciones sueltas para poder soltarlos en [_soltarSocket]: tomados de
  // `this` son siempre iguales entre sí.
  void _alIntentarReconectar(dynamic _) =>
      _emitConnectionStatus(ConnectionStatus.reconnecting);

  void _alFallarLaReconexion(dynamic _) =>
      _emitConnectionStatus(ConnectionStatus.disconnected);

  /// Cierra el socket actual y suelta todo lo que el servicio le colgó,
  /// también lo que cuelga de su `Manager`.
  void _soltarSocket() {
    final socket = _socket;
    if (socket == null) return;
    socket.io
      ..off('reconnect_attempt', _alIntentarReconectar)
      ..off('reconnect_error', _alFallarLaReconexion);
    socket.dispose();
    _socket = null;
  }

  /// Deserializa un payload del socket de forma defensiva: datos
  /// malformados no deben tumbar el callback ni la suscripción.
  Map<String, dynamic>? _asMap(Object? data) {
    if (data is! Map) return null;
    try {
      return Map<String, dynamic>.from(data);
    } catch (_) {
      return null;
    }
  }

  @override
  Stream<ConnectionStatus> get connectionStateStream =>
      _connectionStateController.stream;
  @override
  Stream<Map<String, dynamic>> get busPositionStream =>
      _busPositionController.stream;
  @override
  Stream<Map<String, dynamic>> get batchPositionStream =>
      _batchPositionController.stream;
  @override
  Stream<Map<String, dynamic>> get busLeftStream => _busLeftController.stream;
  @override
  Stream<Map<String, dynamic>> get busHiddenStream =>
      _busHiddenController.stream;
  @override
  Stream<Map<String, dynamic>> get busVisibleStream =>
      _busVisibleController.stream;
  @override
  Stream<Map<String, dynamic>> get busRemovedStream =>
      _busRemovedController.stream;

  @override
  void connect() => _zona.run(_conectar);

  void _conectar() {
    _quiereConexion = true;
    if (_socket?.connected == true) return;
    _soltarSocket();
    final url = _backendUrl;
    _emitConnectionStatus(ConnectionStatus.reconnecting);
    _socket = _crearSocket(url, <String, dynamic>{
      'transports': ['websocket'],
      'path': AppConfig.wsPath,
      'autoConnect': true,
      'reconnection': true,
      'reconnectionDelay': 1000,
      'reconnectionDelayMax': 10000,
      'randomizationFactor': 0.3,
      // Un `Manager` propio para cada socket. Sin esto `io.io` devolvía el
      // que ya tenía guardado para el mismo servidor, con su mismo socket, y
      // cada vuelta de conectar le colgaba otro par de `onReconnect*`.
      'forceNew': true,
    });

    // Reintento infinito aunque el paquete agote sus intentos: con la red
    // inestable no debe quedarse muerto para siempre hasta reiniciar la app.
    _retryTimer ??= Timer.periodic(const Duration(seconds: 15), (_) {
      if (_disposed) return;
      final socket = _socket;
      if (socket != null && !socket.connected) {
        socket.connect();
      }
    });

    _socket!.onConnect((_) {
      _emitConnectionStatus(ConnectionStatus.connected);
      for (final routeId in _subscriptions) {
        _socket!.emit('subscribe:route', routeId);
      }
    });
    _socket!.onDisconnect(
        (_) => _emitConnectionStatus(ConnectionStatus.disconnected));
    _socket!.onReconnectAttempt(_alIntentarReconectar);
    _socket!.onReconnectError(_alFallarLaReconexion);
    _socket!.onConnectError(
        (_) => _emitConnectionStatus(ConnectionStatus.disconnected));
    _socket!.on(
        'error', (_) => _emitConnectionStatus(ConnectionStatus.disconnected));

    _socket!.on('bus:position', (data) {
      final event = _asMap(data);
      if (event == null) return;
      _medidor.registrar(event);
      _emit(_busPositionController, event);
    });
    _socket!.on('positions:update', (data) {
      final update = _asMap(data);
      if (update == null) return;
      final buses = update['buses'];
      if (buses is List) {
        for (final bus in buses) {
          if (bus is Map) {
            final position = _asMap(bus);
            if (position != null) {
              _medidor.registrar(position);
              _emit(_busPositionController, position);
            }
          }
        }
      }
    });
    _socket!.on('positions:batch', (data) {
      final batch = _asMap(data);
      if (batch == null) return;
      final buses = batch['buses'];
      if (buses is List) {
        for (final bus in buses) {
          final position = _asMap(bus);
          if (position != null) _medidor.registrar(position);
        }
      }
      _emit(_batchPositionController, batch);
    });
    _socket!.on('bus:left', (data) {
      final event = _asMap(data);
      if (event != null) _emit(_busLeftController, event);
    });
    _socket!.on('bus:hidden', (data) {
      final event = _asMap(data);
      if (event != null) _emit(_busHiddenController, event);
    });
    _socket!.on('bus:visible', (data) {
      final event = _asMap(data);
      if (event == null) return;
      final position = _asMap(event['position']);
      if (position != null) _medidor.registrar(position);
      _emit(_busVisibleController, event);
    });
    _socket!.on('bus:removed', (data) {
      final event = _asMap(data);
      if (event != null) _emit(_busRemovedController, event);
    });
  }

  /// Pasa el socket a [url] sin perder lo que la app seguía.
  ///
  /// Cambia solo el socket de debajo: el servicio y sus streams son los
  /// mismos, así que el mapa, que ya los escucha, sigue recibiendo sin
  /// enterarse, y las rutas se vuelven a pedir solas al conectar. Si la app
  /// no quiere conexión en este momento, solo se guarda la URL para el
  /// próximo [connect].
  void cambiarBackend(String url) {
    if (url == _backendUrl) return;
    _backendUrl = url;
    if (_disposed || !_quiereConexion) return;
    _zona.run(_soltarSocket);
    connect();
  }

  @override
  void subscribeToRoute(String routeId) {
    _subscriptions.add(routeId);
    _socket?.emit('subscribe:route', routeId);
  }

  /// Cierra el socket y detiene el reintento, pero sin destruir el servicio:
  /// el mapa puede volver a [connect] con el mismo provider.
  @override
  void disconnect() {
    _quiereConexion = false;
    _supervisor?.detener();
    _retryTimer?.cancel();
    _retryTimer = null;
    _subscriptions.clear();
    _zona.run(() => _socket?.disconnect());
  }

  @override
  void unsubscribeFromRoute(String routeId) {
    _subscriptions.remove(routeId);
    _socket?.emit('unsubscribe:route', routeId);
  }

  @override
  void dispose() {
    _disposed = true;
    _quiereConexion = false;
    _retryTimer?.cancel();
    _retryTimer = null;
    _subscriptions.clear();
    _zona.run(_soltarSocket);
    _connectionStateController.close();
    _busPositionController.close();
    _batchPositionController.close();
    _busLeftController.close();
    _busHiddenController.close();
    _busVisibleController.close();
    _busRemovedController.close();
  }

  @override
  bool get isConnected => _socket?.connected ?? false;

  @override
  ConnectionStatus? get lastConnectionState => _lastConnectionState;
}
