import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

Widget _host({bool sinAnimaciones = false, Color? color}) {
  return MediaQuery(
    data: MediaQueryData(disableAnimations: sinAnimaciones),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: IndicadorCarga(color: color, semanticsLabel: 'Un momento'),
      ),
    ),
  );
}

List<Color> _coloresDeLosPuntos(WidgetTester tester) {
  return tester
      .widgetList<Container>(find.byType(Container))
      .map((c) => (c.decoration! as BoxDecoration).color!)
      .toList();
}

void main() {
  testWidgets('son tres puntos y se anuncian con su rótulo', (tester) async {
    await tester.pumpWidget(_host());
    await tester.pump();

    expect(find.byType(Container), findsNWidgets(3));
    expect(find.bySemanticsLabel('Un momento'), findsOneWidget);
  });

  testWidgets('los puntos no se encienden a la vez: la espera avanza',
      (tester) async {
    await tester.pumpWidget(_host());
    // A un tercio del ciclo los tres llevan intensidades distintas. Si
    // coincidieran, esto sería un parpadeo y no un movimiento.
    await tester.pump(AppMotion.pulso ~/ 3);

    final alfas = _coloresDeLosPuntos(tester).map((c) => c.a).toList();
    expect(alfas.toSet().length, 3);
  });

  testWidgets('con movimiento reducido se queda quieto', (tester) async {
    await tester.pumpWidget(_host(sinAnimaciones: true));
    await tester.pump();
    final antes = _coloresDeLosPuntos(tester);

    await tester.pump(AppMotion.pulso ~/ 2);
    expect(_coloresDeLosPuntos(tester), antes);
    // Y sigue siendo la misma forma: tres puntos, no un hueco.
    expect(antes.length, 3);
  });

  testWidgets('lleva el color que se le pide', (tester) async {
    await tester.pumpWidget(_host(color: const Color(0xFFFFFFFF)));
    await tester.pump();

    for (final color in _coloresDeLosPuntos(tester)) {
      expect(color.r, 1.0);
      expect(color.g, 1.0);
      expect(color.b, 1.0);
    }
  });

  testWidgets('al desmontar no queda animación viva', (tester) async {
    await tester.pumpWidget(_host());
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpWidget(const SizedBox());
    // Sin `dispose` del controlador, el ticker seguiría pidiendo cuadros y
    // esto no terminaría nunca.
    await tester.pumpAndSettle();
  });
}
