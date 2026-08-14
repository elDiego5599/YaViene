import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

import 'prefs_keys.dart';

/// Reencuentra la última ruta elegida: la app abre donde quedaste, no en el
/// mapa genérico de la ciudad. Solo restaura si aún no hay ruta seleccionada
/// (p. ej. tras cerrar sesión e iniciar de nuevo). Recibe un
/// [ProviderContainer] para ser testeable; en producción se obtiene con
/// `ProviderScope.containerOf(context)`.
Future<void> restoreLastRoute(ProviderContainer container) async {
  final prefs = await SharedPreferences.getInstance();
  final savedRouteId = prefs.getString(PrefsKeys.savedRouteId);
  final savedCompanyId = prefs.getString(PrefsKeys.savedCompanyId);
  if (savedRouteId == null || savedCompanyId == null) return;

  final current = container.read(selectedRouteProvider);
  if (current != null) {
    final company = container.read(selectedCompanyProvider);
    if (company != null) {
      await persistRouteSelection(container, current.id, company.id);
    }
    return;
  }

  final routes = container.read(routesByCompanyProvider(savedCompanyId));
  if (routes.hasValue) {
    _applySavedRoute(container, routes.value!, savedRouteId);
    return;
  }
  container.listen(routesByCompanyProvider(savedCompanyId), (previous, next) {
    next.whenData((list) {
      if (container.read(selectedRouteProvider) == null) {
        _applySavedRoute(container, list, savedRouteId);
      }
    });
  });
}

/// Guarda la ruta elegida para reencontrarla en el próximo arranque.
Future<void> persistRouteSelection(
    ProviderContainer container, String routeId, String companyId) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(PrefsKeys.savedRouteId, routeId);
  await prefs.setString(PrefsKeys.savedCompanyId, companyId);
}

void _applySavedRoute(
    ProviderContainer container, List<RouteInfo> routes, String routeId) {
  for (final route in routes) {
    if (route.id == routeId) {
      container.read(selectedRouteProvider.notifier).select(route);
      return;
    }
  }
}