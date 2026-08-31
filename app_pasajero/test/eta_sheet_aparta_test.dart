import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/map_view_state.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/user_location_provider.dart';
import 'package:ya_viene_pasajero/features/map/presentation/widgets/eta_bottom_sheet.dart';

class _TestUserLocation extends UserLocationNotifier {
  void set(UserLocationState state) => this.state = state;
}

/// Con el selector de ruta arriba, la hoja de distancia se aparta.
///
/// Las dos se apoyan en el mismo borde inferior de la pantalla: la tarjeta
/// de "Escoge empresa y ruta" asomaba por debajo del selector, y bajar el
/// selector descubría otra tarjeta en lugar del mapa. Se aparta mientras se
/// elige y vuelve al cerrarse el selector —también, y sobre todo, cuando no
/// se eligió ninguna ruta.
void main() {
  Future<ProviderContainer> pump(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer(overrides: [
      userLocationProvider.overrideWith((ref) => _TestUserLocation()),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: EtaBottomSheet())),
      ),
    );
    await tester.pump();
    (container.read(userLocationProvider.notifier) as _TestUserLocation).set(
      const UserLocationState(
        mode: UserLocationMode.manual,
        lat: 6.2442,
        lon: -75.5812,
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  double opacidad(WidgetTester tester) => tester
      .widget<FadeTransition>(
        find
            .ancestor(
              of: find.byKey(const ValueKey('sheet-handle')),
              matching: find.byType(FadeTransition),
            )
            .first,
      )
      .opacity
      .value;

  bool alcanzable(WidgetTester tester) => !tester
      .widgetList<IgnorePointer>(
        find.ancestor(
          of: find.byKey(const ValueKey('sheet-handle')),
          matching: find.byType(IgnorePointer),
        ),
      )
      .any((w) => w.ignoring);

  testWidgets('se va mientras se elige ruta y vuelve si no se eligió',
      (tester) async {
    final container = await pump(tester);
    expect(find.text('Escoge empresa y ruta'), findsOneWidget);
    expect(opacidad(tester), 1);
    expect(alcanzable(tester), isTrue);

    container.read(routeSelectorOpenProvider.notifier).state = true;
    await tester.pumpAndSettle();
    expect(opacidad(tester), 0, reason: 'no asoma bajo el selector');
    expect(alcanzable(tester), isFalse,
        reason: 'apartada no se puede tocar por debajo del selector');

    // El usuario cierra el selector sin elegir nada: la hoja vuelve sola.
    container.read(routeSelectorOpenProvider.notifier).state = false;
    await tester.pumpAndSettle();
    expect(find.text('Escoge empresa y ruta'), findsOneWidget);
    expect(opacidad(tester), 1);
    expect(alcanzable(tester), isTrue);
  });
}
