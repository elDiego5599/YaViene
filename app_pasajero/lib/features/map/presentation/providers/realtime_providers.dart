import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

import '../../data/services/realtime_service.dart';
import '../../domain/repositories/realtime_repository.dart';

final realtimeServiceProvider = Provider<RealtimeRepository>((ref) {
  // El mismo backend que ya eligió el arranque (`BackendResolver`), no la
  // constante de compilación: si el túnel principal está caído, el socket
  // tiene que irse al respaldo con todo lo demás.
  final service = RealtimeService(ref.watch(backendUrlProvider));
  ref.onDispose(() => service.dispose());
  return service;
});

final connectionStateProvider =
    StreamProvider.autoDispose<ConnectionStatus>((ref) {
  final repo = ref.watch(realtimeServiceProvider);
  return _connectionStateWithInitial(repo);
});

/// Re-emite el último estado conocido al arrancar: el stream del servicio es
/// broadcast y tras un logout→login el provider se recrea y quedaría en
/// blanco hasta el siguiente evento del socket.
Stream<ConnectionStatus> _connectionStateWithInitial(
    RealtimeRepository repo) async* {
  final last = repo.lastConnectionState;
  if (last != null) yield last;
  yield* repo.connectionStateStream;
}
