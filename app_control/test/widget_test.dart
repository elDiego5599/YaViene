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
}
