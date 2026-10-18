import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import 'package:ya_viene_pasajero/core/router/app_router.dart';
import 'package:ya_viene_pasajero/core/widgets/ink_hero.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/tracking_providers.dart';
import 'package:ya_viene_pasajero/features/notifications/presentation/providers/proximity_alerts_provider.dart';
import 'package:ya_viene_pasajero/features/splash/presentation/screens/splash_screen.dart';
import 'package:ya_viene_pasajero/features/splash/presentation/widgets/escena_arranque.dart';

/// El arranque (dueño, 2026-10-18): fondo blanco, Barranquilla que se arma
/// —la Ventana al Mundo, la cayena y el bus— y la marca. Breve: la escena
/// entera dura [EscenaArranque.duracion] y el arranque sigue apenas termina.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<GoRouter> abrir(WidgetTester tester) async {
    final container = ProviderContainer(overrides: [
      backendUrlProvider.overrideWith(() => BackendUrl.fija('http://x')),
      busPositionsSourceProvider.overrideWith(
        (ref, routeId) => const Stream.empty(),
      ),
      proximityAlertsProvider.overrideWith(
        (ref) => ProximityAlertsNotifier(ref,
            notify: ({
              required String busId,
              String? routeName,
              String? routeId,
              required int distanceMeters,
            }) async =>
                true),
      ),
    ]);
    addTearDown(container.dispose);
    final router = container.read(appRouterProvider);
    addTearDown(router.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    return router;
  }

  testWidgets('el arranque es blanco y pinta la escena con la marca',
      (tester) async {
    await abrir(tester);
    await tester.pump();

    final fondo = tester.widget<Scaffold>(find.descendant(
      of: find.byType(SplashScreen),
      matching: find.byType(Scaffold),
    ));
    expect(fondo.backgroundColor, Colors.white);
    expect(find.byType(EscenaArranque), findsOneWidget);
    expect(find.text('Ya Viene'), findsOneWidget);
    // El logo sigue volando a la bienvenida.
    expect(
      find.byWidgetPredicate((w) => w is Hero && w.tag == InkHero.marcaHeroTag),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Abriendo Ya Viene'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('sigue apenas termina la escena, ni antes ni mucho después',
      (tester) async {
    final router = await abrir(tester);
    await tester.pump();
    await tester
        .pump(EscenaArranque.duracion - const Duration(milliseconds: 50));
    expect(router.routeInformationProvider.value.uri.path, '/');

    await tester.pump(const Duration(milliseconds: 100));
    // La bienvenida respira para siempre: se avanza un tiempo fijo.
    await tester.pump(const Duration(seconds: 1));
    expect(router.routeInformationProvider.value.uri.path, '/onboarding');
  });

  testWidgets('la escena es breve: menos de un segundo y medio',
      (tester) async {
    expect(EscenaArranque.duracion.inMilliseconds, lessThan(1500));
  });

  testWidgets('con «Reducir movimiento» sale armada y quieta', (tester) async {
    var termino = false;
    await tester.pumpWidget(MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: MaterialApp(
        home: Scaffold(
          body: Center(child: EscenaArranque(alTerminar: () => termino = true)),
        ),
      ),
    ));
    await tester.pump();
    // Sin animación: ningún cuadro pide repintar.
    expect(tester.binding.hasScheduledFrame, isFalse);
    final torre = tester.widget<CustomPaint>(find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is PintorVentana));
    expect((torre.painter! as PintorVentana).avance, 1);
    expect(termino, isFalse);
    await tester.pump(EscenaArranque.quieta);
    expect(termino, isTrue);
  });
}
