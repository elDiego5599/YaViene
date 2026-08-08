import 'dart:async';

import 'package:flutter/foundation.dart';
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
  final _busRemovedController = StreamController<String>.broadcast();
  final _connectionController = StreamController<bool>.broadcast();
  final _sessionKickedController = StreamController<void>.broadcast();

  Stream<List<FleetBus>> get busBatchStream => _busBatchController.stream;
  Stream<FleetBus> get busPositionStream => _busPositionController.stream;
  Stream<String> get busHiddenStream => _busHiddenController.stream;
  Stream<FleetBus> get busVisibleStream => _busVisibleController.stream;
  Stream<String> get busLeftStream => _busLeftController.stream;
  Stream<String> get busRemovedStream => _busRemovedController.stream;
  Stream<bool> get connectionStream => _connectionController.stream;

  /// El servidor cerró la conexión (token inválido/revocado) → sesión muerta.
  Stream<void> get sessionKickedStream => _sessionKickedController.stream;

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

    void emit<T>(StreamController<T> controller, T value) {
      if (!controller.isClosed) controller.add(value);
    }

    socket.onConnect((_) {
      emit(_connectionController, true);
      socket.emit('subscribe:fleet');
    });
    socket.onDisconnect((reason) {
      emit(_connectionController, false);
      // 'io server disconnect' = el backend nos desconectó (p.ej. token
      // inválido al suscribirse). No tiene sentido reintentar: la sesión
      // murió. Sin este aviso la app quedaría reconectando en loop.
      if (reason == 'io server disconnect') {
        emit(_sessionKickedController, null);
      }
    });
    socket.onConnectError((_) => emit(_connectionController, false));
    socket.onReconnectAttempt((_) => emit(_connectionController, false));
    socket.on('error', (_) => emit(_connectionController, false));

    socket.on('fleet:batch', (data) {
      debugPrint('[fleet-socket] fleet:batch recibido');
      final buses = (data['buses'] as List)
          .map((b) => FleetBus.fromJson(Map<String, dynamic>.from(b as Map)))
          .toList();
      emit(_busBatchController, buses);
    });

    socket.on('bus:position', (data) {
      emit(
        _busPositionController,
        FleetBus.fromJson(Map<String, dynamic>.from(data as Map)),
      );
    });

    socket.on('bus:hidden', (data) {
      debugPrint('[fleet-socket] bus:hidden ${data['busId']} event=${data['eventId']}');
      emit(_busHiddenController, data['busId'] as String);
    });

    socket.on('bus:visible', (data) {
      debugPrint('[fleet-socket] bus:visible ${data['busId']} event=${data['eventId']}');
      final position = data['position'];
      if (position != null) {
        emit(
          _busVisibleController,
          FleetBus.fromJson(Map<String, dynamic>.from(position as Map)),
        );
      } else {
        emit(
          _busVisibleController,
          FleetBus.fromJson(Map<String, dynamic>.from(data as Map)),
        );
      }
    });

    socket.on('bus:left', (data) {
      emit(_busLeftController, data['busId'] as String);
    });

    socket.on('bus:removed', (data) {
      debugPrint('[fleet-socket] bus:removed ${data['busId']} event=${data['eventId']}');
      emit(_busRemovedController, data['busId'] as String);
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
    _busRemovedController.close();
    _connectionController.close();
    _sessionKickedController.close();
  }
}
