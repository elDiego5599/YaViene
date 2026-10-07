@Tags(['goldens'])
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/'
    'tracking_providers.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/'
    'user_location_provider.dart';
import 'package:ya_viene_pasajero/features/notifications/presentation/'
    'providers/alert_history_provider.dart';
import 'package:ya_viene_pasajero/features/notifications/presentation/'
    'screens/notifications_screen.dart';

import 'golden_harness.dart';

/// El centro de avisos: lleno y vacío.
///
/// El historial se siembra a mano con fechas fijas. Si se armara un aviso
/// de verdad, la entrada quedaría con `DateTime.now()` y la foto cambiaría
/// cada vez que se corre la prueba.
class _UbicacionDePrueba extends UserLocationNotifier {
  _UbicacionDePrueba() {
    state = const UserLocationState(
      mode: UserLocationMode.manual,
      lat: 6.2442,
      lon: -75.5812,
    );
  }
}

class _HistorialSembrado extends AlertHistoryNotifier {
  _HistorialSembrado(List<AlertHistoryEntry> entradas) {
    state = entradas;
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> montar(
    WidgetTester tester,
    List<AlertHistoryEntry> historial,
  ) async {
    final container = ProviderContainer(overrides: [
      userLocationProvider.overrideWith((ref) => _UbicacionDePrueba()),
      alertHistoryProvider.overrideWith((ref) => _HistorialSembrado(historial)),
      busPositionsSourceProvider.overrideWith(
        (ref, routeId) => Stream.value(const <BusPosition>[]),
      ),
    ]);
    addTearDown(container.dispose);
    final sub = container.listen<RouteInfo?>(selectedRouteProvider, (_, __) {});
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
  }

  testWidgets('avisos · vacío', (tester) async {
    fijarPantalla(tester);
    await montar(tester, const []);
    await coincideConOro(tester, 'avisos_vacio');
  });

  testWidgets('avisos · uno activo y uno enviado', (tester) async {
    fijarPantalla(tester);
    await montar(tester, [
      AlertHistoryEntry(
        busId: 'BUS-WFK042',
        routeId: 'R1',
        routeName: 'Ruta 106',
        createdAt: DateTime(2026, 3, 14, 7, 40),
      ),
      AlertHistoryEntry(
        busId: 'BUS-ABC123',
        routeId: 'R1',
        routeName: 'Ruta 106',
        createdAt: DateTime(2026, 3, 14, 6, 55),
        sentAt: DateTime(2026, 3, 14, 7, 12),
      ),
    ]);
    await coincideConOro(tester, 'avisos_lleno');
  });
}
