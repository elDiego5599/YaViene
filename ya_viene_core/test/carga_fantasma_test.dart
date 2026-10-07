import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

Widget _host({bool sinAnimaciones = false}) {
  return MediaQuery(
    data: MediaQueryData(disableAnimations: sinAnimaciones),
    child: const Directionality(
      textDirection: TextDirection.ltr,
      child: CargaFantasma(
        semanticsLabel: 'Cargando las rutas',
        child: Text('fila de mentira'),
      ),
    ),
  );
}

double _opacidad(WidgetTester tester) =>
    tester.widget<Opacity>(find.byType(Opacity)).opacity;

void main() {
  testWidgets('se anuncia con su rótulo y no lee lo que dibuja', (
    tester,
  ) async {
    await tester.pumpWidget(_host());

    expect(find.bySemanticsLabel('Cargando las rutas'), findsOneWidget);
    // Las filas fantasma son forma, no texto: un lector no debe leerlas.
    expect(find.bySemanticsLabel('fila de mentira'), findsNothing);
  });

  testWidgets('dentro de otra cosa con rótulo, sigue diciendo el suyo', (
    tester,
  ) async {
    // En el panel la lista vive dentro de una tarjeta: sin nodo propio, el
    // rótulo se fundía con el de arriba y el lector no lo decía solo.
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Semantics(label: 'Buses', child: _host()),
      ),
    );

    expect(find.bySemanticsLabel('Cargando las rutas'), findsOneWidget);
  });

  testWidgets('late: la opacidad va y vuelve', (tester) async {
    await tester.pumpWidget(_host());
    final antes = _opacidad(tester);

    await tester.pump(AppMotion.pulso ~/ 2);
    expect(_opacidad(tester), isNot(antes));
  });

  testWidgets('con movimiento reducido se queda quieta y sin ticker', (
    tester,
  ) async {
    await tester.pumpWidget(_host(sinAnimaciones: true));
    final antes = _opacidad(tester);

    await tester.pump(AppMotion.pulso ~/ 2);
    expect(_opacidad(tester), antes);
    expect(tester.hasRunningAnimations, isFalse);
  });
}
