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
    _applySavedRoute(container, routes.value!, savedRouteId, savedCompanyId);
    return;
  }
  // Las rutas aún no cargaron: se aplican en cuanto lleguen y se cierra la
  // suscripción (no debe quedar viva en el contenedor raíz).
  late final ProviderSubscription<AsyncValue<List<RouteInfo>>> sub;
  sub = container.listen<AsyncValue<List<RouteInfo>>>(
    routesByCompanyProvider(savedCompanyId),
    (previous, next) {
      if (!next.hasValue) return;
      if (container.read(selectedRouteProvider) == null) {
        _applySavedRoute(container, next.value!, savedRouteId, savedCompanyId);
      }
      sub.close();
    },
  );
}

/// Guarda la ruta elegida para reencontrarla en el próximo arranque.
Future<void> persistRouteSelection(
    ProviderContainer container, String routeId, String companyId) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(PrefsKeys.savedRouteId, routeId);
  await prefs.setString(PrefsKeys.savedCompanyId, companyId);
}

void _applySavedRoute(
    ProviderContainer container, List<RouteInfo> routes, String routeId, String companyId) {
  for (final route in routes) {
    if (route.id == routeId) {
      // La empresa se restaura antes de la ruta: si la hoja de selección se
      // abre, la ruta no queda "activa" sin empresa detrás (antes bloqueaba
      // el cambio con 'Primero selecciona una empresa').
      _restoreCompany(container, companyId);
      container.read(selectedRouteProvider.notifier).select(route);
      return;
    }
  }
}

/// Selecciona la empresa guardada (busca el objeto real en la lista, para
/// mostrar su nombre y no solo el id). Si las empresas aún no cargaron, se
/// queda a la espera de la primera emisión y cierra la suscripción.
void _restoreCompany(ProviderContainer container, String companyId) {
  final companies = container.read(companiesProvider);
  if (companies.hasValue) {
    _selectCompanyById(container, companies.value!, companyId);
    return;
  }
  late final ProviderSubscription<AsyncValue<List<Company>>> sub;
  sub = container.listen<AsyncValue<List<Company>>>(
    companiesProvider,
    (previous, next) {
      if (!next.hasValue) return;
      _selectCompanyById(container, next.value!, companyId);
      sub.close();
    },
  );
}

void _selectCompanyById(
    ProviderContainer container, List<Company> companies, String companyId) {
  for (final company in companies) {
    if (company.id == companyId) {
      container.read(selectedCompanyProvider.notifier).select(company);
      return;
    }
  }
}