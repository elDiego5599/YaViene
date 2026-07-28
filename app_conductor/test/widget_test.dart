import 'package:flutter_test/flutter_test.dart';

import 'package:ya_viene_conductor/main.dart';

void main() {
  testWidgets('App loads login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const YaVieneConductorApp());
    expect(find.text('Acceso Conductores'), findsOneWidget);
  });
}
