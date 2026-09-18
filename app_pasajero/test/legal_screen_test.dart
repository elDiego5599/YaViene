import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  testWidgets('el router lleva a cada documento por su camino',
      (tester) async {
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
