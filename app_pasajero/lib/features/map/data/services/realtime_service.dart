import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:ya_viene_core/ya_viene_core.dart';
import '../../domain/repositories/realtime_repository.dart';
import '../../../../config.dart';

class RealtimeService implements RealtimeRepository {
  io.Socket? _socket;
  final _subscriptions = <String>{};
  final _connectionStateController = StreamController<ConnectionStatus>.broadcast();
  final _busPositionController = StreamController<Map<String, dynamic>>.broadcast();
  final _batchPositionController = StreamController<Map<String, dynamic>>.broadcast();
  final _busLeftController = StreamController<Map<String, dynamic>>.broadcast();
  final _busHiddenController = StreamController<Map<String, dynamic>>.broadcast();
  final _busVisibleController = StreamController<Map<String, dynamic>>.broadcast();
  final _busRemovedController = StreamController<Map<String, dynamic>>.broadcast();

  @override
  Stream<ConnectionStatus> get connectionStateStream => _connectionStateController.stream;
  @override
  Stream<Map<String, dynamic>> get busPositionStream => _busPositionController.stream;
  @override
  Stream<Map<String, dynamic>> get batchPositionStream => _batchPositionController.stream;
  @override
  Stream<Map<String, dynamic>> get busLeftStream => _busLeftController.stream;
  @override
  Stream<Map<String, dynamic>> get busHiddenStream => _busHiddenController.stream;
  @override
  Stream<Map<String, dynamic>> get busVisibleStream => _busVisibleController.stream;
  @override
  Stream<Map<String, dynamic>> get busRemovedStream => _busRemovedController.stream;

  @override
  void connect() {
    if (_socket?.connected == true) return;
    _socket?.dispose();
    const url = AppConfig.backendUrl;
    _connectionStateController.add(ConnectionStatus.reconnecting);
    _socket = io.io(url, <String, dynamic>{
      'transports': ['websocket'],
      'path': AppConfig.wsPath,
      'autoConnect': true,
      'reconnection': true,
      'reconnectionAttempts': 10,
      'reconnectionDelay': 1000,
      'reconnectionDelayMax': 10000,
      'randomizationFactor': 0.3,
    });

    _socket!.onConnect((_) {
      _connectionStateController.add(ConnectionStatus.connected);
      for (final routeId in _subscriptions) {
        _socket!.emit('subscribe:route', routeId);
      }
    });
    _socket!.onDisconnect((_) => _connectionStateController.add(ConnectionStatus.disconnected));
    _socket!.onReconnectAttempt((_) => _connectionStateController.add(ConnectionStatus.reconnecting));
    _socket!.onConnectError((_) => _connectionStateController.add(ConnectionStatus.disconnected));
    _socket!.on('error', (_) => _connectionStateController.add(ConnectionStatus.disconnected));

    _socket!.on('bus:position', (data) {
      _busPositionController.add(Map<String, dynamic>.from(data as Map));
    });
    _socket!.on('positions:batch', (data) {
      final batch = Map<String, dynamic>.from(data as Map);
      _batchPositionController.add(batch);
    });
    _socket!.on('bus:left', (data) {
      _busLeftController.add(Map<String, dynamic>.from(data as Map));
    });
    _socket!.on('bus:hidden', (data) {
      _busHiddenController.add(Map<String, dynamic>.from(data as Map));
    });
    _socket!.on('bus:visible', (data) {
      _busVisibleController.add(Map<String, dynamic>.from(data as Map));
    });
    _socket!.on('bus:removed', (data) {
      _busRemovedController.add(Map<String, dynamic>.from(data as Map));
    });
  }

  @override
  void subscribeToRoute(String routeId) {
    _subscriptions.add(routeId);
    _socket?.emit('subscribe:route', routeId);
  }

  @override
  void unsubscribeFromRoute(String routeId) {
    _subscriptions.remove(routeId);
    _socket?.emit('unsubscribe:route', routeId);
  }

  @override
  void dispose() {
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
}
