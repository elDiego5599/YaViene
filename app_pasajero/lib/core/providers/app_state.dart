import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

import '../../services/background_keep_alive.dart';
import '../../features/map/presentation/providers/realtime_providers.dart';
import '../../features/map/presentation/providers/tracking_providers.dart';
import '../../features/map/presentation/providers/user_location_provider.dart';
import '../../features/notifications/presentation/providers/proximity_alerts_provider.dart';
import '../prefs_keys.dart';
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
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(PrefsKeys.savedRouteId);
  await prefs.remove(PrefsKeys.savedCompanyId);
  await ref.read(userLocationProvider.notifier).clearManualPin();
}

/// Arranque en frío: limpia el estado efímero (selecciones, avisos, sockets)
/// SIN tocar la persistencia (ruta/empresa guardadas ni el pin manual). Es la
/// diferencia con [resetAppState] (logout): al reabrir la app el usuario
/// reencuentra su ruta y su pin, y `restoreLastRoute` vuelve a funcionar.
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
