import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/pin_hint_provider.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/user_location_provider.dart';
import 'package:ya_viene_pasajero/features/map/presentation/widgets/location_status_chip.dart';

/// La única explicación de que el pin se arrastra vive en la píldora.
///
/// Antes esa frase estaba en el estado vacío de la hoja de distancia: se
/// mostraba solo cuando NO había pin, o sea desaparecía justo en el momento
/// en que se volvía cierta. Y lo que quedaba sobre el mapa era un círculo de
/// cuatro flechas, sin palabras, que no se retiraba nunca.
class _ManualLocation extends UserLocationNotifier {
  _ManualLocation() {
    state = UserLocationState(
      mode: UserLocationMode.manual,
      lat: 10.99,
      lon: -74.79,
      updatedAt: DateTime(2026),
    );
  }
}

void main() {
  Future<void> pumpChip(WidgetTester tester, ProviderContainer container) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: Center(child: LocationStatusChip())),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('la primera vez la píldora explica que el pin se arrastra',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer(overrides: [
      userLocationProvider.overrideWith((ref) => _ManualLocation()),
    ]);
    addTearDown(container.dispose);

    await pumpChip(tester, container);
    expect(find.text('Tu punto de espera'), findsOneWidget);
    expect(find.text('Arrástralo para moverlo'), findsOneWidget);
  });

  testWidgets('quien ya lo arrastró no vuelve a ver la pista', (tester) async {
    SharedPreferences.setMockInitialValues({'pin_drag_learned': true});
    final container = ProviderContainer(overrides: [
      userLocationProvider.overrideWith((ref) => _ManualLocation()),
    ]);
    addTearDown(container.dispose);

    await pumpChip(tester, container);
    expect(find.text('Tu punto de espera'), findsOneWidget);
    expect(find.text('Arrástralo para moverlo'), findsNothing);
  });

  test('markLearned se recuerda entre sesiones', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    // Primera sesión: aún no lo sabe.
    expect(container.read(pinDragLearnedProvider), isTrue); // sin cargar
    await Future<void>.delayed(Duration.zero);
    expect(container.read(pinDragLearnedProvider), isFalse);

    await container.read(pinDragLearnedProvider.notifier).markLearned();
    expect(container.read(pinDragLearnedProvider), isTrue);

    // Segunda sesión: lo lee del disco.
    final otra = ProviderContainer();
    addTearDown(otra.dispose);
    otra.read(pinDragLearnedProvider);
    await Future<void>.delayed(Duration.zero);
    expect(otra.read(pinDragLearnedProvider), isTrue);
  });
}
