import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import 'package:ya_viene_pasajero/core/providers/auth_provider.dart';
import 'package:ya_viene_pasajero/features/auth/presentation/screens/'
    'login_screen.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/'
    'map_tour_provider.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/'
    'tracking_providers.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/'
    'user_location_provider.dart';
import 'package:ya_viene_pasajero/features/map/presentation/widgets/'
    'eta_bottom_sheet.dart';
import 'package:ya_viene_pasajero/features/map/presentation/widgets/'
    'route_selector_sheet.dart';
import 'package:ya_viene_pasajero/features/map/presentation/widgets/'
    'search_pill_bar.dart';
import 'package:ya_viene_pasajero/features/notifications/presentation/'
    'providers/alert_history_provider.dart';
import 'package:ya_viene_pasajero/features/notifications/presentation/'
    'screens/notifications_screen.dart';
import 'package:ya_viene_pasajero/features/onboarding/presentation/screens/'
    'onboarding_screen.dart';

import 'golden/golden_harness.dart';

/// El texto del sistema en grande, en las seis superficies principales.
///
/// Una caja de alto fijo con letra dentro no avisa: se desborda en el
/// teléfono de alguien, no en el CI. Estas pruebas la obligan a avisar
/// aquí, y en los dos tamaños que importan:
///
/// * **135%** es el mayor que iOS ofrece sin entrar en accesibilidad. Ahí
///   no vale ningún techo: la app tiene que crecer.
/// * **300%** es territorio de accesibilidad. Ahí sí hay dos hojas con
///   techo —la de distancia y la del selector se paran en el 200%, que es
///   lo que pide la WCAG— pero ninguna puede recortar lo que muestra.
const List<double> kEscalas = [1.35, 3.0];

class _AutenticacionFalsa implements AuthNotifier {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    switch (invocation.memberName) {
      case #state:
        return const AuthState();
      case #isEmailValid:
        return true;
      case #checkEmail:
        return Future<bool>.value(true);
      default:
        return null;
    }
  }
}

class _UbicacionDePrueba extends UserLocationNotifier {
  _UbicacionDePrueba() {
    state = const UserLocationState(
      mode: UserLocationMode.manual,
      lat: _lat,
      lon: _lon,
    );
  }
}

const double _lat = 6.2442;
const double _lon = -75.5812;

BusPosition _bus(double desfase) => BusPosition(
      busId: 'A-1',
      routeId: 'R1',
      lat: _lat + desfase,
      lon: _lon,
      heading: 0,
      speedKmh: 30,
      timestamp: DateTime(2026, 1, 1, 8),
      isGhostBus: false,
    );

/// Denuncia cualquier desbordamiento ocurrido durante el montaje.
///
/// `takeException` devuelve el primero; si hubo más, el marco los imprime
/// enteros por consola antes de resumirlos, así que el detalle no se
/// pierde.
void sinDesbordes(WidgetTester tester, String pantalla, double escala) {
  expect(
    tester.takeException(),
    isNull,
    reason: '$pantalla se desborda con el texto al '
        '${(escala * 100).round()}%.',
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final escala in kEscalas) {
    group('texto al ${(escala * 100).round()}%', () {
    testWidgets('bienvenida', (tester) async {
      fijarPantalla(tester, escalaTexto: escala);
      await tester.pumpWidget(
        ProviderScope(child: marcoGoldenRuteado(const OnboardingScreen())),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 900));
      sinDesbordes(tester, 'La bienvenida', escala);
    });

    testWidgets('inicio de sesión', (tester) async {
      fijarPantalla(tester, escalaTexto: escala);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => _AutenticacionFalsa()),
          ],
          child: marcoGoldenRuteado(const LoginScreen(), ruta: '/login'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 900));
      sinDesbordes(tester, 'El inicio de sesión', escala);
    });

    testWidgets('píldora de búsqueda con ruta', (tester) async {
      fijarPantalla(tester, escalaTexto: escala);
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.listen(selectedRouteProvider, (_, __) {});
      container.read(selectedRouteProvider.notifier).select(
            const RouteInfo(
              id: 'R-106',
              name: 'Ruta 106 · Centro',
              companyId: 'EMP-01',
            ),
          );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: marcoGolden(
            const ColoredBox(
              color: Color(0xFFE8E6E1),
              child: Align(
                alignment: Alignment.topCenter,
                child: SearchPillBar(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      sinDesbordes(tester, 'La píldora de búsqueda', escala);
    });

    testWidgets('selector de empresa y ruta', (tester) async {
      fijarPantalla(tester, escalaTexto: escala);
      final guia = MapGuideNotifier();
      await guia.initialize(
        userId: 'texto-grande',
        isNewUser: false,
        hasLocation: true,
        locationSettled: true,
        hasRoute: false,
        hasSelectedBus: false,
        hasActiveAlert: false,
      );
      final container = ProviderContainer(overrides: [
        mapGuideProvider.overrideWith((ref) => guia),
        companiesProvider.overrideWith(
          (ref) async => const [Company(id: 'EMP-01', name: 'Sobusa')],
        ),
        routesByCompanyProvider.overrideWith(
          (ref, id) async => const [
            RouteInfo(
              id: 'R-106',
              name: 'Ruta 106',
              companyId: 'EMP-01',
              terminalA: 'Terminal',
              terminalB: 'Centro',
            ),
          ],
        ),
      ]);
      addTearDown(container.dispose);
      container.listen(selectedCompanyProvider, (_, __) {});
      container.listen(selectedRouteProvider, (_, __) {});
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: marcoGolden(
            Builder(
              builder: (context) => Center(
                child: TextButton(
                  onPressed: () => RouteSelectorSheet.show(
                    context,
                    sheet: const RouteSelectorSheet(),
                  ),
                  child: const Text('abrir'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      sinDesbordes(tester, 'El selector', escala);
    });

    testWidgets('hoja de distancia', (tester) async {
      fijarPantalla(tester, escalaTexto: escala);
      final container = ProviderContainer(overrides: [
        userLocationProvider.overrideWith((ref) => _UbicacionDePrueba()),
        busPositionsSourceProvider.overrideWith(
          (ref, routeId) => Stream.value([_bus(0.007645)]),
        ),
        routeTrajectoryProvider.overrideWith(
          (ref, routeId) => RouteTrajectory(
            routeId: routeId,
            routeName: 'Ruta 1',
            points: const [
              GeoPoint(lat: _lat, lon: _lon - 0.05),
              GeoPoint(lat: _lat, lon: _lon + 0.05),
            ],
          ),
        ),
      ]);
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: marcoGolden(
            const ColoredBox(
              color: Color(0xFFE8E6E1),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: EtaBottomSheet(),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      container.read(selectedRouteProvider.notifier).select(
            const RouteInfo(id: 'R1', name: 'Ruta 1', companyId: 'C1'),
          );
      container.read(selectedBusesProvider.notifier).toggleBus('A-1');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      sinDesbordes(tester, 'La hoja de distancia', escala);
    });

    testWidgets('centro de avisos', (tester) async {
      fijarPantalla(tester, escalaTexto: escala);
      final container = ProviderContainer(overrides: [
        userLocationProvider.overrideWith((ref) => _UbicacionDePrueba()),
        alertHistoryProvider.overrideWith((ref) => _HistorialSembrado()),
        busPositionsSourceProvider.overrideWith(
          (ref, routeId) => Stream.value(const <BusPosition>[]),
        ),
      ]);
      addTearDown(container.dispose);
      final sub =
          container.listen<RouteInfo?>(selectedRouteProvider, (_, __) {});
      addTearDown(sub.close);
      container.read(selectedRouteProvider.notifier).select(
            const RouteInfo(id: 'R1', name: 'Ruta 106', companyId: 'EMP-01'),
          );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: marcoGolden(const NotificationsScreen()),
        ),
      );
      await tester.pumpAndSettle();
      sinDesbordes(tester, 'El centro de avisos', escala);
    });
    });
  }
}

class _HistorialSembrado extends AlertHistoryNotifier {
  _HistorialSembrado() {
    state = [
      AlertHistoryEntry(
        busId: 'B-042',
        routeId: 'R1',
        routeName: 'Ruta 106',
        createdAt: DateTime(2026, 3, 14, 7, 40),
      ),
      AlertHistoryEntry(
        busId: 'B-055',
        routeId: 'R1',
        routeName: 'Ruta 106',
        createdAt: DateTime(2026, 3, 14, 6, 55),
        sentAt: DateTime(2026, 3, 14, 7, 12),
      ),
    ];
  }
}
