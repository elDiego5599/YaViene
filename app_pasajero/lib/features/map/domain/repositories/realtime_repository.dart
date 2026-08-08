import 'dart:async';
import 'package:ya_viene_core/ya_viene_core.dart';

abstract class RealtimeRepository {
  Stream<ConnectionStatus> get connectionStateStream;
  Stream<Map<String, dynamic>> get busPositionStream;
  Stream<Map<String, dynamic>> get batchPositionStream;
  Stream<Map<String, dynamic>> get busLeftStream;
  Stream<Map<String, dynamic>> get busHiddenStream;
  Stream<Map<String, dynamic>> get busVisibleStream;
  Stream<Map<String, dynamic>> get busRemovedStream;

  void connect();
  void subscribeToRoute(String routeId);
  void unsubscribeFromRoute(String routeId);
  void dispose();
  bool get isConnected;
}
