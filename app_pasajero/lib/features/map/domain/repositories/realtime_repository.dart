import 'dart:async';
import 'package:ya_viene_core/ya_viene_core.dart';

abstract class RealtimeRepository {
  Stream<ConnectionStatus> get connectionStateStream;
  Stream<Map<String, dynamic>> get busPositionStream;
  Stream<List<Map<String, dynamic>>> get batchPositionStream;
  Stream<String> get busLeftStream;

  void connect();
  void subscribeToRoute(String routeId);
  void unsubscribeFromRoute(String routeId);
  void dispose();
  bool get isConnected;
}
