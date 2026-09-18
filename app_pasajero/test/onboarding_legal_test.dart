import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import 'package:ya_viene_pasajero/features/legal/legal_acceptance.dart';
import 'package:ya_viene_pasajero/features/onboarding/presentation/screens/'
    'onboarding_screen.dart';

import 'golden/golden_harness.dart';

/// La bienvenida no deja pasar hasta que se aceptan los dos documentos.
///
/// Los dos botones salen apagados: el que pide la ubicación y el que la
/// deja para después. Aceptar no es un trámite escondido en letra chica al
/// pie —"al continuar aceptas"—, es un toque que el usuario da.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  /// La bienvenida con un mapa de verdad detrás al que salir.
  Future<GoRouter> abrirBienvenida(WidgetTester tester) async {
    fijarPantalla(tester);
    final router = GoRouter(
      initialLocation: '/onboarding',
      routes: [
        GoRoute(
          path: '/onboarding',
          builder: (context, state) => const OnboardingScreen(),
        ),
        GoRoute(
          path: '/map',
          builder: (context, state) => const Scaffold(body: Text('el mapa')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          locale: const Locale('es', 'CO'),
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
    return router;
  }

  bool apagado(WidgetTester tester, Finder boton) =>
      tester.widget<ButtonStyleButton>(boton).onPressed == null;

  testWidgets('sin aceptar, ninguno de los dos botones hace nada',
      (tester) async {
    await abrirBienvenida(tester);

    expect(apagado(tester, find.byType(ElevatedButton)), isTrue);
    expect(apagado(tester, find.byType(TextButton)), isTrue);
  });

  testWidgets('al aceptar se encienden los dos', (tester) async {
    await abrirBienvenida(tester);

    await tester.tap(find.byKey(const ValueKey('legal_accept')));
    await tester.pump();

    expect(apagado(tester, find.byType(ElevatedButton)), isFalse);
    expect(apagado(tester, find.byType(TextButton)), isFalse);
  });

  testWidgets('los dos botones caben en la pantalla sin desplazarse',
      (tester) async {
    await abrirBienvenida(tester);

    // El sí añadió una fila a una hoja que ya llegaba justo. Si los botones
    // se van por debajo del filo, la primera pantalla de la app pide un
    // desplazamiento que nada anuncia.
    expect(
      tester.getBottomLeft(find.byType(TextButton)).dy,
      lessThanOrEqualTo(kPantalla.height),
    );
  });

  testWidgets('dejar la ubicación para después también guarda el sí',
      (tester) async {
    final router = await abrirBienvenida(tester);

    await tester.tap(find.byKey(const ValueKey('legal_accept')));
    await tester.pump();
    await tester.tap(find.byType(TextButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(await isLegalAccepted(), isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('onboarding_seen'), isTrue);
    expect(router.routeInformationProvider.value.uri.path, '/map');
  });

  testWidgets('los dos documentos se abren desde la propia bienvenida',
      (tester) async {
    await abrirBienvenida(tester);

    expect(find.byKey(const ValueKey('legal_link_privacidad')), findsOneWidget);
    expect(find.byKey(const ValueKey('legal_link_terminos')), findsOneWidget);
  });
}
