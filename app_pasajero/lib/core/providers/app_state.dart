import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

import '../../features/map/presentation/providers/tracking_providers.dart';
import '../../features/map/presentation/providers/user_location_provider.dart';
import '../../features/notifications/presentation/providers/proximity_alerts_provider.dart';
import '../prefs_keys.dart';

/// Deja la app "recién instalada": sin ruta seleccionada, sin buses
/// seleccionados, sin avisos activos y sin el pin manual guardado.
/// Se llama al abrir la pantalla de inicio de sesión y al cerrar sesión.
Future<void> resetAppState(WidgetRef ref) async {
  ref.read(selectedRouteProvider.notifier).clear();
  ref.read(selectedBusesProvider.notifier).clear();
  ref.read(activeAlertsProvider.notifier).clear();
  ref.read(proximityAlertsProvider.notifier).clear();
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(PrefsKeys.savedRouteId);
  await prefs.remove(PrefsKeys.savedCompanyId);
  await ref.read(userLocationProvider.notifier).clearManualPin();
}
