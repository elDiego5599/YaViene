import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import 'package:ya_viene_pasajero/core/router/app_router.dart';
import 'package:ya_viene_pasajero/features/legal/legal_docs.dart';
import 'package:ya_viene_pasajero/features/legal/presentation/screens/'
    'legal_screen.dart';

import 'golden/golden_harness.dart';

/// Los documentos se leen dentro de la app, sin navegador.
///
/// Abrirlos en la web obligaría a instalar `url_launcher` y a que el
/// teléfono tenga señal justo en la pantalla donde todavía no ha aceptado
/// nada. El texto viaja en la app y se lee ahí mismo.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  /// Los fondos de las pantallas son blancos y lo blanco que va encima se
  /// despega con sombra (dueño, 2026-10-16). La barra de arriba, del mismo
  /// blanco: si no, se lee como una franja de otro papel.
  void exigeFondoBlanco(WidgetTester tester) {
    expect(tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
        AppColors.surface,
        reason: 'el fondo de los documentos');
    expect(tester.widget<AppBar>(find.byType(AppBar)).backgroundColor,
        AppColors.surface,
        reason: 'la barra de los documentos');
  }

  testWidgets('cada documento se lee entero con su fecha', (tester) async {
    for (final doc in legalDocs) {
      fijarPantalla(tester);
      await tester.pumpWidget(marcoGolden(LegalScreen(doc: doc)));
      await tester.pump();

      expect(find.text(doc.title), findsOneWidget);
      expect(find.textContaining(doc.updated), findsOneWidget);
      final primerTitular =
          doc.blocks.firstWhere((b) => b.kind == LegalBlockKind.heading);
      expect(find.text(primerTitular.text), findsOneWidget);
    }
  });

  testWidgets('los documentos van sobre blanco', (tester) async {
    fijarPantalla(tester);
    await tester.pumpWidget(marcoGolden(LegalScreen(doc: legalDocs.first)));
    await tester.pump();
    exigeFondoBlanco(tester);
  });

  testWidgets('el router lleva a cada documento por su camino', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final router = container.read(appRouterProvider);
    addTearDown(router.dispose);

    router.go('/legal/terminos');
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();

    expect(find.byType(LegalScreen), findsOneWidget);
    expect(find.text(legalTerminos.title), findsOneWidget);
  });

  testWidgets('un documento que no existe no rompe la app', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final router = container.read(appRouterProvider);
    addTearDown(router.dispose);

    router.go('/legal/inventado');
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();

    expect(find.text('Ruta no encontrada'), findsOneWidget);
  });
}
