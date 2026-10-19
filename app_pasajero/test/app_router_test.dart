import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ya_viene_pasajero/core/router/app_router.dart';
import 'package:ya_viene_pasajero/core/router/pestanas_deslizantes.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/tracking_providers.dart';
import 'package:ya_viene_pasajero/features/notifications/presentation/providers/proximity_alerts_provider.dart';
import 'package:ya_viene_pasajero/features/notifications/presentation/screens/notifications_screen.dart';

/// El pasajero entra sin cuenta (D3): el backend nunca usó la sesión para
/// nada, así que el login solo era una puerta delante del mapa. Estas
/// pruebas fijan que el router ya no pide cuenta para llegar a ninguna
/// pantalla y que `/login` dejó de existir.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<GoRouter> abrir(WidgetTester tester, String ruta) async {
    final container = ProviderContainer(overrides: [
      busPositionsSourceProvider.overrideWith(
        (ref, routeId) => const Stream.empty(),
      ),
      // La notificación de verdad no tiene canal en un test.
      proximityAlertsProvider.overrideWith(
        (ref) => ProximityAlertsNotifier(ref,
            notify: ({
              required String busId,
              String? routeName,
              String? routeId,
              String? companyId,
              required int distanceMeters,
            }) async =>
                true),
      ),
    ]);
    addTearDown(container.dispose);
    final router = container.read(appRouterProvider);
    addTearDown(router.dispose);
    // Se navega antes del primer frame para no pasar por el splash, que
    // arranca temporizadores y servicios que aquí no interesan.
    router.go(ruta);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    return router;
  }

  testWidgets('sin cuenta, los avisos se abren sin pasar por un login',
      (tester) async {
    final router = await abrir(tester, '/notifications');

    expect(router.routeInformationProvider.value.uri.path, '/notifications');
    expect(find.byType(NotificationsScreen), findsOneWidget);
  });

  testWidgets('las pestañas van en el carrete que las desliza', (tester) async {
    await abrir(tester, '/notifications');

    final carrete =
        tester.widget<PestanasDeslizantes>(find.byType(PestanasDeslizantes));
    expect(carrete.indice, 1);
    expect(carrete.children, hasLength(4));
  });

  testWidgets('/login ya no es una ruta', (tester) async {
    await abrir(tester, '/login');

    expect(find.text('Ruta no encontrada'), findsOneWidget);
  });

  test('ninguna ruta del router es la del login', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final router = container.read(appRouterProvider);
    addTearDown(router.dispose);

    // Las pestañas viven dentro del shell: se recorre el árbol entero.
    Iterable<String> caminos(List<RouteBase> rutas) => rutas.expand((r) => [
          if (r is GoRoute) r.path,
          ...caminos(r.routes),
        ]);
    final rutas = caminos(router.configuration.routes).toList();
    expect(rutas, isNot(contains('/login')));
    expect(rutas, containsAll(['/', '/onboarding', '/map', '/notifications']));
  });
}
