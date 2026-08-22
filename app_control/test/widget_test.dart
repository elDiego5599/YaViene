import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ya_viene_control/main.dart';

void main() {
  testWidgets('app boots on narrow viewport', (tester) async {
    await tester.binding.setSurfaceSize(const Size(600, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const ProviderScope(child: YaVieneControlApp()),
    );
    expect(find.byType(Scaffold), findsOneWidget);
  });

  testWidgets('login renders on wide viewport', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1600, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const ProviderScope(child: YaVieneControlApp()),
    );
    await tester.pumpAndSettle();
    expect(find.text('YA VIENE'), findsOneWidget);
    expect(find.text('INGRESAR'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
