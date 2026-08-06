import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../../../config.dart';
import '../domain/fleet_bus.dart';

class FleetSocketService {
  FleetSocketService({required this.token});

  final String token;

  io.Socket? _socket;
  final _busBatchController = StreamController<List<FleetBus>>.broadcast();
  final _busPositionController = StreamController<FleetBus>.broadcast();
  final _busHiddenController = StreamController<String>.broadcast();
  final _busVisibleController = StreamController<FleetBus>.broadcast();
  final _busLeftController = StreamController<String>.broadcast();
  final _connectionController = StreamController<bool>.broadcast();

  Stream<List<FleetBus>> get busBatchStream => _busBatchController.stream;
  Stream<FleetBus> get busPositionStream => _busPositionController.stream;
  Stream<String> get busHiddenStream => _busHiddenController.stream;
  Stream<FleetBus> get busVisibleStream => _busVisibleController.stream;
  Stream<String> get busLeftStream => _busLeftController.stream;
  Stream<bool> get connectionStream => _connectionController.stream;

  bool get isConnected => _socket?.connected == true;

  void connect() {
    if (_socket?.connected == true) return;
    _socket?.dispose();

    final socket = io.io(AppConfig.backendUrl, <String, dynamic>{
      'transports': ['websocket'],
      'path': AppConfig.wsPath,
      'autoConnect': true,
      'reconnection': true,
      'reconnectionAttempts': 20,
      'reconnectionDelay': 1000,
      'reconnectionDelayMax': 10000,
      'randomizationFactor': 0.3,
      'auth': {'token': token},
    });
    _socket = socket;

    socket.onConnect((_) {
      _connectionController.add(true);
      socket.emit('subscribe:fleet');
    });
    socket.onDisconnect((_) => _connectionController.add(false));
    socket.onConnectError((_) => _connectionController.add(false));
    socket.onReconnectAttempt((_) => _connectionController.add(false));
    socket.on('error', (_) => _connectionController.add(false));

    socket.on('fleet:batch', (data) {
      final buses = (data['buses'] as List)
          .map((b) => FleetBus.fromJson(Map<String, dynamic>.from(b as Map)))
          .toList();
      _busBatchController.add(buses);
    });

    socket.on('bus:position', (data) {
      _busPositionController.add(FleetBus.fromJson(Map<String, dynamic>.from(data as Map)));
    });

    socket.on('bus:hidden', (data) {
      _busHiddenController.add(data['busId'] as String);
    });

    socket.on('bus:visible', (data) {
      final position = data['position'];
      if (position != null) {
        _busVisibleController.add(FleetBus.fromJson(Map<String, dynamic>.from(position as Map)));
      } else {
        _busVisibleController.add(FleetBus.fromJson(Map<String, dynamic>.from(data as Map)));
      }
    });

    socket.on('bus:left', (data) {
      _busLeftController.add(data['busId'] as String);
    });
  }

  void dispose() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _busBatchController.close();
    _busPositionController.close();
    _busHiddenController.close();
    _busVisibleController.close();
    _busLeftController.close();
    _connectionController.close();
  }
}
