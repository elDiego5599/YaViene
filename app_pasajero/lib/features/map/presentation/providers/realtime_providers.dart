import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:ya_viene_core/ya_viene_core.dart';

import '../../data/services/realtime_service.dart';
import '../../domain/repositories/realtime_repository.dart';

/// Cómo se abre el socket en vivo. Existe para las pruebas: la app usa el de
/// `socket_io_client`.
final realtimeSocketFactoryProvider =
    Provider<RealtimeSocketFactory>((ref) => io.io);

final realtimeServiceProvider = Provider<RealtimeRepository>((ref) {
  // El mismo backend que ya eligió el arranque (`BackendResolver`), no la
  // constante de compilación: si el túnel principal está caído, el socket
  // tiene que irse al respaldo con todo lo demás.
  //
  // Se lee una vez y después se escucha, en vez de `watch`: con `watch`, un
  // cambio de backend con la app abierta tiraba el servicio entero, y con él
  // los streams que el mapa ya escuchaba. Así solo cambia el socket.
  final supervisor = BackendSupervisor(
    reResolver: ref.read(backendUrlProvider.notifier).reResolver,
  );
  final service = RealtimeService(
    ref.read(backendUrlProvider),
    supervisor: supervisor,
    crearSocket: ref.watch(realtimeSocketFactoryProvider),
  );
  ref.listen<String>(
      backendUrlProvider, (_, url) => service.cambiarBackend(url));
  ref.onDispose(() {
    supervisor.dispose();
    service.dispose();
  });
  return service;
});

final connectionStateProvider =
    StreamProvider.autoDispose<ConnectionStatus>((ref) {
  final repo = ref.watch(realtimeServiceProvider);
  return _connectionStateWithInitial(repo);
});

/// Re-emite el último estado conocido al arrancar: el stream del servicio es
/// broadcast y, cuando el provider se recrea (al volver al mapa), quedaría
/// en blanco hasta el siguiente evento del socket.
Stream<ConnectionStatus> _connectionStateWithInitial(
    RealtimeRepository repo) async* {
  final last = repo.lastConnectionState;
  if (last != null) yield last;
  yield* repo.connectionStateStream;
}
