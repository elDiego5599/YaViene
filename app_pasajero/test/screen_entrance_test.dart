import 'package:ya_viene_pasajero/core/widgets/entrance.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host({bool sinAnimaciones = false}) {
  return MediaQuery(
    data: MediaQueryData(disableAnimations: sinAnimaciones),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: ScreenEntrance(
        builder: (context, entra) => Column(
          children: [
            entra(const Text('primero')),
            entra(const Text('segundo'), start: 0.5),
          ],
        ),
      ),
    ),
  );
}

double _opacidad(WidgetTester tester, String texto) {
  final fade = tester.widget<FadeTransition>(
    find.ancestor(of: find.text(texto), matching: find.byType(FadeTransition)),
  );
  return fade.opacity.value;
}

Offset _posicion(WidgetTester tester, String texto) {
  final slide = tester.widget<SlideTransition>(
    find.ancestor(of: find.text(texto), matching: find.byType(SlideTransition)),
  );
  return slide.position.value;
}

void main() {
  testWidgets('cada elemento entra en su turno y termina visible',
      (tester) async {
    await tester.pumpWidget(_host());

    expect(_opacidad(tester, 'primero'), 0.0);
    expect(_opacidad(tester, 'segundo'), 0.0);

    // A mitad del grupo el primero ya entró y el segundo aún no arranca:
    // el desfase es real, no dos elementos moviéndose a la vez.
    await tester.pump(const Duration(milliseconds: 350));
    expect(_opacidad(tester, 'primero'), greaterThan(0.8));
    expect(_opacidad(tester, 'segundo'), lessThan(0.4));

    await tester.pumpAndSettle();
    expect(_opacidad(tester, 'primero'), 1.0);
    expect(_opacidad(tester, 'segundo'), 1.0);
    expect(_posicion(tester, 'segundo'), Offset.zero);
  });

  testWidgets('con movimiento reducido se funde pero no se desplaza',
      (tester) async {
    await tester.pumpWidget(_host(sinAnimaciones: true));

    expect(_posicion(tester, 'primero'), Offset.zero);
    expect(_opacidad(tester, 'primero'), 0.0);

    await tester.pumpAndSettle();
    expect(_opacidad(tester, 'primero'), 1.0);
  });

  testWidgets('al desmontar no quedan animaciones vivas', (tester) async {
    await tester.pumpWidget(_host());
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpWidget(const SizedBox());
    // Si el controlador o alguna curva quedara sin desechar, el assert de
    // tickers pendientes de flutter_test haría fallar aquí.
    expect(find.byType(ScreenEntrance), findsNothing);
  });
}
