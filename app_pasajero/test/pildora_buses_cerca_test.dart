// «Haz que no varíe el texto de "n buses cerca de tu punto" sin importar si
// usa GPS o pin» (dueño, 2026-10-26): con el GPS decía «Usando tu
// ubicación, n buses cerca».
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/nearby_buses_provider.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/user_location_provider.dart';
import 'package:ya_viene_pasajero/features/map/presentation/widgets/location_status_chip.dart';

class _Ubicacion extends UserLocationNotifier {
  _Ubicacion(UserLocationState inicial) {
    state = inicial;
  }
}

void main() {
  for (final modo in [UserLocationMode.gps, UserLocationMode.manual]) {
    for (final (n, texto) in const [
      (1, '1 bus cerca de tu punto'),
      (3, '3 buses cerca de tu punto'),
    ]) {
      testWidgets('con ${modo.name} y $n cerca dice «$texto»', (tester) async {
        SharedPreferences.setMockInitialValues({'pin_drag_learned': true});
        final container = ProviderContainer(overrides: [
          userLocationProvider.overrideWith((ref) => _Ubicacion(
                UserLocationState(mode: modo, lat: 10.99, lon: -74.79),
              )),
          nearbyBusesCountProvider('R1').overrideWith((ref) => n),
        ]);
        addTearDown(container.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: Scaffold(
                body: Center(child: LocationStatusChip(routeId: 'R1')),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(texto), findsOneWidget);
      });
    }
  }
}
