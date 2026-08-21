import 'dart:async';
import 'package:ya_viene_core/ya_viene_core.dart';

abstract class RealtimeRepository {
  Stream<ConnectionStatus> get connectionStateStream;

  /// Último estado conocido de conexión (`null` si aún no hubo ninguno):
  /// permite al UI restaurar el chip tras recrear el provider.
  ConnectionStatus? get lastConnectionState;
  Stream<Map<String, dynamic>> get busPositionStream;
  Stream<Map<String, dynamic>> get batchPositionStream;
  Stream<Map<String, dynamic>> get busLeftStream;
  Stream<Map<String, dynamic>> get busHiddenStream;
  Stream<Map<String, dynamic>> get busVisibleStream;
  Stream<Map<String, dynamic>> get busRemovedStream;

  void connect();
  void subscribeToRoute(String routeId);
  void unsubscribeFromRoute(String routeId);

  /// Cierra el socket y detiene el reintento sin destruir el servicio
  /// (un login posterior puede reconectar con el mismo provider).
  void disconnect();
  void dispose();
  bool get isConnected;
}
