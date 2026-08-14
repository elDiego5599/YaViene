import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import 'package:ya_viene_pasajero/core/prefs_keys.dart';
import 'package:ya_viene_pasajero/core/route_restore.dart';

void main() {
  const savedRoute = RouteInfo(
    id: 'R-106',
    name: 'Ruta 106',
    companyId: 'EMP-01',
  );
  const otherRoute = RouteInfo(
    id: 'R-104',
    name: 'Ruta 104',
    companyId: 'EMP-01',
  );

  ProviderContainer buildContainer({
    List<RouteInfo>? routes,
    Future<List<RouteInfo>> Function()? routesLoader,
  }) {
    return ProviderContainer(
      overrides: [
        routesByCompanyProvider.overrideWith(
          (ref, companyId) async =>
              routesLoader != null ? await routesLoader() : routes ?? [],
        ),
      ],
    );
  }

  /// Mantiene vivo `selectedRouteProvider` como lo hace el `map_screen` en
  /// producción (que lo `watch` en build): `autoDispose` descarta el estado
  /// si no hay listener, y la restauración quedaría invisible en el test.
  void keepRouteAlive(ProviderContainer container) {
    container.listen(selectedRouteProvider, (_, __) {});
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('restaura la última ruta guardada cuando las rutas ya cargaron', () async {
    await persistRouteSelection(ProviderContainer(), savedRoute.id, 'EMP-01');
    final container = buildContainer(routes: [savedRoute, otherRoute]);
    keepRouteAlive(container);
    await container.read(routesByCompanyProvider('EMP-01').future);

    await restoreLastRoute(container);

    expect(container.read(selectedRouteProvider)?.id, savedRoute.id);
  });

  test('no pisa una ruta ya seleccionada (p. ej. tras cerrar sesión)', () async {
    await persistRouteSelection(ProviderContainer(), savedRoute.id, 'EMP-01');
    final container = buildContainer(routes: [savedRoute, otherRoute]);
    keepRouteAlive(container);
    container.read(selectedRouteProvider.notifier).select(otherRoute);

    await restoreLastRoute(container);

    expect(container.read(selectedRouteProvider)?.id, otherRoute.id);
  });

  test('sin ruta guardada no selecciona nada', () async {
    final container = buildContainer(routes: [savedRoute]);
    keepRouteAlive(container);

    await restoreLastRoute(container);

    expect(container.read(selectedRouteProvider), isNull);
  });

  test('restaura cuando las rutas terminan de cargar (ruta lenta)', () async {
    await persistRouteSelection(ProviderContainer(), savedRoute.id, 'EMP-01');
    final completer = Completer<List<RouteInfo>>();
    final container = buildContainer(routesLoader: () => completer.future);
    keepRouteAlive(container);

    await restoreLastRoute(container);
    expect(container.read(selectedRouteProvider), isNull);

    completer.complete([savedRoute]);
    await pumpEventQueue();

    expect(container.read(selectedRouteProvider)?.id, savedRoute.id);
  });

  test('persiste la ruta y la compañía para el próximo arranque', () async {
    await persistRouteSelection(ProviderContainer(), savedRoute.id, 'EMP-01');

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(PrefsKeys.savedRouteId), savedRoute.id);
    expect(prefs.getString(PrefsKeys.savedCompanyId), 'EMP-01');
  });

  test('guardada una ruta que ya no existe en la compañía: no restaura', () async {
    await persistRouteSelection(ProviderContainer(), 'R-999', 'EMP-01');
    final container = buildContainer(routes: [savedRoute, otherRoute]);

    await restoreLastRoute(container);

    expect(container.read(selectedRouteProvider), isNull);
  });
}
