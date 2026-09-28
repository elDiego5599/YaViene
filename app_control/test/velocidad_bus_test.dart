// La velocidad del bus seleccionado, en grande en su ficha. Iba pegada al
// «Último reporte» en letra de 10,5 pt («ahora · 32 km/h»): el dato que un
// operador busca primero cuando toca un bus quedaba como una nota al pie.
//
// Solo se enseña con el bus en línea (quien la monta pasa `null` si no): la
// velocidad de un bus callado es de hace rato y ya no dice nada. Y un valor
// que ningún bus puede llevar —negativo, NaN, infinito— tampoco se pinta.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_control/features/fleet/presentation/widgets/velocidad_bus.dart';

void main() {
  Future<void> montar(WidgetTester tester, double? kmh) => tester.pumpWidget(
    MaterialApp(home: Scaffold(body: VelocidadBus(kmh: kmh))),
  );

  testWidgets('la cifra redondeada, grande, con su unidad aparte', (
    tester,
  ) async {
    await montar(tester, 31.6);
    expect(find.text('32'), findsOneWidget);
    expect(find.text('km/h'), findsOneWidget);
    expect(find.text('VELOCIDAD'), findsOneWidget);
    final cifra = tester.widget<Text>(find.text('32'));
    final unidad = tester.widget<Text>(find.text('km/h'));
    expect(cifra.style!.fontSize, greaterThan(unidad.style!.fontSize! * 2));
    // Cifras de ancho fijo: de 9 a 10 km/h la ficha no baila.
    expect(
      cifra.style!.fontFeatures,
      contains(const FontFeature.tabularFigures()),
    );
  });

  testWidgets('parado dice 0, no lo esconde', (tester) async {
    await montar(tester, 0.3);
    expect(find.text('0'), findsOneWidget);
  });

  testWidgets('sin dato: una raya, sin unidad', (tester) async {
    for (final kmh in <double?>[null, -4, double.nan, double.infinity]) {
      await montar(tester, kmh);
      expect(find.text('—'), findsOneWidget, reason: '$kmh');
      expect(find.text('km/h'), findsNothing, reason: '$kmh');
    }
  });

  testWidgets('el lector de pantalla oye una sola frase', (tester) async {
    final semantica = tester.ensureSemantics();
    await montar(tester, 32);
    expect(find.bySemanticsLabel('Velocidad: 32 km/h'), findsOneWidget);
    await montar(tester, null);
    expect(find.bySemanticsLabel('Velocidad: sin dato'), findsOneWidget);
    semantica.dispose();
  });

  testWidgets('pinta en su propia capa', (tester) async {
    await montar(tester, 32);
    expect(
      find.descendant(
        of: find.byType(VelocidadBus),
        matching: find.byType(RepaintBoundary),
      ),
      findsOneWidget,
    );
  });
}
