import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:ya_viene_core/ya_viene_core.dart';
import '../../domain/repositories/realtime_repository.dart';
import '../../../../config.dart';

class RealtimeService implements RealtimeRepository {
  io.Socket? _socket;
  final _connectionStateController = StreamController<ConnectionStatus>.broadcast();
  final _busPositionController = StreamController<Map<String, dynamic>>.broadcast();
  final _batchPositionController = StreamController<List<Map<String, dynamic>>>.broadcast();
  final _busLeftController = StreamController<String>.broadcast();

  @override
  Stream<ConnectionStatus> get connectionStateStream => _connectionStateController.stream;
  @override
  Stream<Map<String, dynamic>> get busPositionStream => _busPositionController.stream;
  @override
  Stream<List<Map<String, dynamic>>> get batchPositionStream => _batchPositionController.stream;
  @override
  Stream<String> get busLeftStream => _busLeftController.stream;

  @override
  void connect() {
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

    _socket!.onConnect((_) => _connectionStateController.add(ConnectionStatus.connected));
    _socket!.onDisconnect((_) => _connectionStateController.add(ConnectionStatus.disconnected));
    _socket!.onReconnectAttempt((_) => _connectionStateController.add(ConnectionStatus.reconnecting));

    _socket!.on('bus:position', (data) {
      _busPositionController.add(data as Map<String, dynamic>);
    });
    _socket!.on('positions:batch', (data) {
      final batch = data as Map<String, dynamic>;
      final buses = batch['buses'] as List<dynamic>;
      _batchPositionController.add(buses.cast<Map<String, dynamic>>());
    });
    _socket!.on('bus:left', (data) {
      final busId = (data as Map<String, dynamic>)['busId'] as String?;
      if (busId != null) _busLeftController.add(busId);
    });
  }

  @override
  void subscribeToRoute(String routeId) {
    _socket?.emit('subscribe:route', routeId);
  }

  @override
  void unsubscribeFromRoute(String routeId) {
    _socket?.emit('unsubscribe:route', routeId);
  }

  @override
  void dispose() {
    _socket?.disconnect();
    _socket?.dispose();
    _connectionStateController.close();
    _busPositionController.close();
    _batchPositionController.close();
    _busLeftController.close();
  }

  @override
  bool get isConnected => _socket?.connected ?? false;
}
