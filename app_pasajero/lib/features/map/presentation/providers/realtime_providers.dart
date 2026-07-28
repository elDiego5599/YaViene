import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import '../../domain/repositories/realtime_repository.dart';
import '../../data/services/realtime_service.dart';

final realtimeServiceProvider = Provider<RealtimeRepository>((ref) {
  final service = RealtimeService();
  ref.onDispose(() => service.dispose());
  return service;
});

final connectionStateProvider = StreamProvider.autoDispose<ConnectionStatus>((ref) {
  final repo = ref.watch(realtimeServiceProvider);
  return repo.connectionStateStream;
});
