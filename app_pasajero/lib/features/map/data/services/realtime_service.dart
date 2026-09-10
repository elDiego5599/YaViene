import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:ya_viene_core/ya_viene_core.dart';

import '../../../../config.dart';
import '../../domain/repositories/realtime_repository.dart';

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
  RealtimeService(this._backendUrl);

  final String _backendUrl;

  io.Socket? _socket;
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
  void connect() {
    if (_socket?.connected == true) return;
    _socket?.dispose();
    final url = _backendUrl;
    _emitConnectionStatus(ConnectionStatus.reconnecting);
    _socket = io.io(url, <String, dynamic>{
      'transports': ['websocket'],
      'path': AppConfig.wsPath,
      'autoConnect': true,
      'reconnection': true,
      'reconnectionDelay': 1000,
      'reconnectionDelayMax': 10000,
      'randomizationFactor': 0.3,
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
    _socket!.onReconnectAttempt(
        (_) => _emitConnectionStatus(ConnectionStatus.reconnecting));
    _socket!.onReconnectError(
        (_) => _emitConnectionStatus(ConnectionStatus.disconnected));
    _socket!.onConnectError(
        (_) => _emitConnectionStatus(ConnectionStatus.disconnected));
    _socket!.on(
        'error', (_) => _emitConnectionStatus(ConnectionStatus.disconnected));

    _socket!.on('bus:position', (data) {
      final event = _asMap(data);
      if (event != null) _emit(_busPositionController, event);
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
              _emit(_busPositionController, position);
            }
          }
        }
      }
    });
    _socket!.on('positions:batch', (data) {
      final batch = _asMap(data);
      if (batch != null) _emit(_batchPositionController, batch);
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
      if (event != null) _emit(_busVisibleController, event);
    });
    _socket!.on('bus:removed', (data) {
      final event = _asMap(data);
      if (event != null) _emit(_busRemovedController, event);
    });
  }

  @override
  void subscribeToRoute(String routeId) {
    _subscriptions.add(routeId);
    _socket?.emit('subscribe:route', routeId);
  }

  /// Cierra el socket y detiene el reintento, pero sin destruir el servicio:
  /// un login posterior puede volver a [connect] con el mismo provider.
  @override
  void disconnect() {
    _retryTimer?.cancel();
    _retryTimer = null;
    _subscriptions.clear();
    _socket?.disconnect();
  }

  @override
  void unsubscribeFromRoute(String routeId) {
    _subscriptions.remove(routeId);
    _socket?.emit('unsubscribe:route', routeId);
  }

  @override
  void dispose() {
    _disposed = true;
    _retryTimer?.cancel();
    _retryTimer = null;
    _subscriptions.clear();
    _socket?.disconnect();
    _socket?.dispose();
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
