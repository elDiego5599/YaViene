import 'package:flutter_test/flutter_test.dart';

import 'package:ya_viene_conductor/main.dart';

void main() {
  testWidgets('App loads turn assignment screen in demo mode', (WidgetTester tester) async {
    await tester.pumpWidget(const YaVieneConductorApp());
    expect(find.text('Asignación de Turno'), findsOneWidget);
  });
}
