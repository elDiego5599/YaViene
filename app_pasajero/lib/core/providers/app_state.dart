import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

import '../../services/background_keep_alive.dart';
import '../../features/map/presentation/providers/realtime_providers.dart';
import '../../features/map/presentation/providers/tracking_providers.dart';
import '../../features/map/presentation/providers/user_location_provider.dart';
import '../../features/notifications/presentation/providers/proximity_alerts_provider.dart';
import 'auth_provider.dart';

/// Deja la app "recién instalada": sin ruta seleccionada, sin buses
/// seleccionados, sin avisos activos y sin el pin manual guardado. Además
/// detiene el seguimiento en segundo plano (socket, timer de avisos y el
/// servicio de Android) para que al cerrar sesión no siga consumiendo datos
/// ni batería. Se llama al abrir la pantalla de inicio de sesión y al cerrar
/// sesión.
Future<void> resetAppState(WidgetRef ref) async {
  ref.read(selectedRouteProvider.notifier).clear();
  ref.read(selectedCompanyProvider.notifier).clear();
  ref.read(selectedBusesProvider.notifier).clear();
  ref.read(activeAlertsProvider.notifier).clear();
  ref.read(proximityAlertsProvider.notifier).clear();
  ref.read(proximityAlertsProvider.notifier).stop();
  ref.read(realtimeServiceProvider).disconnect();
  BackgroundKeepAlive.stop();
  await ref.read(userLocationProvider.notifier).clearManualPin();
}

/// Arranque en frío: limpia el estado efímero (selecciones, avisos, sockets)
/// SIN tocar el pin manual guardado, que es lo único que sobrevive al
/// reabrir la app (la ruta se vuelve a elegir cada sesión). Es la
/// diferencia con [resetAppState] (logout).
Future<void> resetTransientState(WidgetRef ref) async {
  ref.read(selectedRouteProvider.notifier).clear();
  ref.read(selectedCompanyProvider.notifier).clear();
  ref.read(selectedBusesProvider.notifier).clear();
  ref.read(activeAlertsProvider.notifier).clear();
  ref.read(proximityAlertsProvider.notifier).clear();
  ref.read(proximityAlertsProvider.notifier).stop();
  ref.read(realtimeServiceProvider).disconnect();
  BackgroundKeepAlive.stop();
}

/// Cierra la sesión completa: resetea el estado de la app (como logout), firma
/// en Firebase y vuelve al inicio de sesión. Lo usan el drawer del mapa y la
/// pantalla de perfil para que ambos caminos hagan exactamente lo mismo.
Future<void> signOutAndGoToLogin(WidgetRef ref, BuildContext context) async {
  await resetAppState(ref);
  await ref.read(authProvider).signOut();
  if (context.mounted) context.go('/login');
}
