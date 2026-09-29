import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

import '../../features/map/presentation/providers/realtime_providers.dart';
import '../../features/map/presentation/providers/tracking_providers.dart';
import '../../features/notifications/presentation/providers/proximity_alerts_provider.dart';
import '../../services/background_keep_alive.dart';

/// Arranque en frío: limpia el estado efímero (selecciones, avisos, sockets)
/// SIN tocar el pin manual guardado, que es lo único que sobrevive al
/// reabrir la app (la ruta se vuelve a elegir cada vez). Los avisos activos
/// tampoco se pierden: viven en el historial y el mapa los re-arma al abrir.
Future<void> resetTransientState(WidgetRef ref) async {
  ref.read(selectedRouteProvider.notifier).clear();
  ref.read(selectedCompanyProvider.notifier).clear();
  ref.read(selectedBusesProvider.notifier).clear();
  ref.read(activeAlertsProvider.notifier).clear();
  ref.read(proximityAlertsProvider.notifier).clear();
  ref.read(proximityAlertsProvider.notifier).stop();
  ref.read(realtimeServiceProvider).disconnect();
  ref.read(servicioDeFondoProvider).apagar();
}
