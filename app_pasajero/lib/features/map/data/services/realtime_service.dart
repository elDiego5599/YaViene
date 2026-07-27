import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:ya_viene_core/ya_viene_core.dart';

class RealtimeService {
  io.Socket? _socket;
  final _connectionStateController = StreamController<ConnectionStatus>.broadcast();
  final _busPositionController = StreamController<Map<String, dynamic>>.broadcast();
  Timer? _mockTimer;

  Stream<ConnectionStatus> get connectionStateStream => _connectionStateController.stream;
  Stream<Map<String, dynamic>> get busPositionStream => _busPositionController.stream;

  void connect(String url) {
    _connectionStateController.add(ConnectionStatus.reconnecting);
    _socket = io.io(url, <String, dynamic>{
      'transports': ['websocket'],
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
    _socket!.on('bus_position', (data) => _busPositionController.add(data as Map<String, dynamic>));
  }

  void startMockStream() {
    _mockTimer?.cancel();
    _connectionStateController.add(ConnectionStatus.connected);
    _mockTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (timer.tick % 5 == 0) {
        _connectionStateController.add(ConnectionStatus.reconnecting);
        Future.delayed(const Duration(seconds: 2), () {
          _connectionStateController.add(ConnectionStatus.connected);
        });
        return;
      }
      _busPositionController.add({
        'busId': 'B-001',
        'routeId': 'R-101',
        'lat': 10.9650 + (timer.tick % 10) * 0.0005,
        'lon': -74.8010 + (timer.tick % 10) * 0.0003,
        'heading': 45.0 + (timer.tick * 5 % 360),
        'speedKmh': 35.0,
        'timestamp': DateTime.now().toIso8601String(),
      });
    });
  }

  void dispose() {
    _mockTimer?.cancel();
    _socket?.disconnect();
    _socket?.dispose();
    _connectionStateController.close();
    _busPositionController.close();
  }
}

final realtimeServiceProvider = Provider<RealtimeService>((ref) {
  final service = RealtimeService();
  ref.onDispose(() => service.dispose());
  return service;
});

final connectionStateProvider = StreamProvider.autoDispose<ConnectionStatus>((ref) {
  final service = ref.watch(realtimeServiceProvider);
  return service.connectionStateStream;
});
