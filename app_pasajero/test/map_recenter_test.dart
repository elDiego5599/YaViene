import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/map_view_state.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/user_location_provider.dart';
import 'package:ya_viene_pasajero/features/map/presentation/widgets/map_recenter_button.dart';

/// El encuadre automático lleva la cámara al punto de espera UNA vez. Sin un
/// botón de volver, el primer arrastre del mapa dejaba al usuario sin manera
/// de regresar a su punto salvo cambiar de ruta.
class _ConPunto extends UserLocationNotifier {
  _ConPunto() {
    state = UserLocationState(
      mode: UserLocationMode.manual,
      lat: 10.99,
      lon: -74.79,
      updatedAt: DateTime(2026),
    );
  }
}

class _SinPunto extends UserLocationNotifier {
  _SinPunto() {
    state = const UserLocationState(mode: UserLocationMode.denied);
  }
}

void main() {
  Future<void> pump(WidgetTester tester, ProviderContainer container) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: Center(child: MapRecenterButton())),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  double opacidad(WidgetTester tester) => tester
      .widget<AnimatedOpacity>(find.byType(AnimatedOpacity).first)
      .opacity;

  testWidgets('con punto de espera el botón está y recentra al tocarlo',
      (tester) async {
    final container = ProviderContainer(overrides: [
      userLocationProvider.overrideWith((ref) => _ConPunto()),
    ]);
    addTearDown(container.dispose);
    container.read(mapPreparingProvider.notifier).state = false;

    await pump(tester, container);
    expect(opacidad(tester), 1);
    expect(container.read(mapRecenterRequestProvider), 0);

    await tester.tap(find.byIcon(Icons.my_location_outlined));
    await tester.pump();
    expect(container.read(mapRecenterRequestProvider), 1);

    // Dos toques seguidos son dos viajes: entre uno y otro el usuario pudo
    // haber arrastrado el mapa, así que el contador tiene que avanzar.
    await tester.tap(find.byIcon(Icons.my_location_outlined));
    await tester.pump();
    expect(container.read(mapRecenterRequestProvider), 2);
  });

  testWidgets('sin punto no hay a dónde volver: el botón no está',
      (tester) async {
    final container = ProviderContainer(overrides: [
      userLocationProvider.overrideWith((ref) => _SinPunto()),
    ]);
    addTearDown(container.dispose);
    container.read(mapPreparingProvider.notifier).state = false;

    await pump(tester, container);
    expect(opacidad(tester), 0);

    await tester.tap(find.byIcon(Icons.my_location_outlined),
        warnIfMissed: false);
    await tester.pump();
    expect(container.read(mapRecenterRequestProvider), 0);
  });

  testWidgets('con el selector abierto el botón se aparta', (tester) async {
    final container = ProviderContainer(overrides: [
      userLocationProvider.overrideWith((ref) => _ConPunto()),
    ]);
    addTearDown(container.dispose);
    container.read(mapPreparingProvider.notifier).state = false;
    container.read(routeSelectorOpenProvider.notifier).state = true;

    await pump(tester, container);
    expect(opacidad(tester), 0);
  });

  testWidgets('mientras el mapa se prepara el botón no aparece',
      (tester) async {
    final container = ProviderContainer(overrides: [
      userLocationProvider.overrideWith((ref) => _ConPunto()),
    ]);
    addTearDown(container.dispose);

    await pump(tester, container);
    expect(opacidad(tester), 0);
  });
}
