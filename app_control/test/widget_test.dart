import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ya_viene_control/main.dart';

void main() {
  testWidgets('app boots', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: YaVieneControlApp()),
    );
    expect(find.byType(Scaffold), findsOneWidget);
  });
}
