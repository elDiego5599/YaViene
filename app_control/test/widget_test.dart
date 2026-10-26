import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ya_viene_control/main.dart';
import 'package:ya_viene_core/core/providers/app_providers.dart'
    show BackendUrl, backendUrlProvider;

// En la app lo pone `main.dart` con lo que resolvió BackendResolver.
final _conBackend = [
  backendUrlProvider.overrideWith(
    () => BackendUrl.fija('http://localhost:3000'),
  ),
];

void main() {
  testWidgets('app boots on narrow viewport', (tester) async {
    await tester.binding.setSurfaceSize(const Size(600, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(overrides: _conBackend, child: const YaVieneControlApp()),
    );
    expect(find.byType(Scaffold), findsOneWidget);
  });

  testWidgets('login renders on wide viewport', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1600, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(overrides: _conBackend, child: const YaVieneControlApp()),
    );
    await tester.pumpAndSettle();
    expect(find.text('YA VIENE'), findsOneWidget);
    expect(find.text('INGRESAR'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // El calendario de «Fecha» en Reportes salía en inglés («October 2026»,
  // S M T W): los textos de los widgets de Material siguen el idioma de la app.
  testWidgets('los widgets de Material hablan español de Colombia', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(overrides: _conBackend, child: const YaVieneControlApp()),
    );
    await tester.pumpAndSettle();
    final contexto = tester.element(find.byType(Scaffold).first);
    expect(Localizations.localeOf(contexto), const Locale('es', 'CO'));
    expect(
      MaterialLocalizations.of(contexto).formatMonthYear(DateTime(2026, 10)),
      'octubre de 2026',
    );
  });
}
