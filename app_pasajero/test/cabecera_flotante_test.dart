import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_pasajero/features/map/presentation/widgets/cabecera_flotante.dart';

Widget _host({required bool apartada, bool sinAnimaciones = false}) {
  return MediaQuery(
    data: MediaQueryData(disableAnimations: sinAnimaciones),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: CabeceraFlotante(
        apartada: apartada,
        child: const Text('píldoras'),
      ),
    ),
  );
}

double _opacidad(WidgetTester tester) =>
    tester.widget<FadeTransition>(find.byType(FadeTransition)).opacity.value;

Offset _desplazamiento(WidgetTester tester) => tester
    .widget<SlideTransition>(find.byType(SlideTransition))
    .position
    .value;

void main() {
  testWidgets('con el selector cerrado la cabecera está en su sitio',
      (tester) async {
    await tester.pumpWidget(_host(apartada: false));
    await tester.pumpAndSettle();

    expect(_opacidad(tester), 1.0);
    expect(_desplazamiento(tester), Offset.zero);
    expect(tester.widget<IgnorePointer>(find.byType(IgnorePointer)).ignoring,
        isFalse);
  });

  testWidgets('con el selector abierto se levanta y se apaga', (tester) async {
    await tester.pumpWidget(_host(apartada: false));
    await tester.pumpAndSettle();

    await tester.pumpWidget(_host(apartada: true));
    await tester.pumpAndSettle();

    expect(_opacidad(tester), 0.0);
    // Hacia arriba: la hoja de abajo se hunde, esta sale por su propio borde.
    expect(_desplazamiento(tester).dy, lessThan(0));
    // Apagada y además intocable: media píldora asomando sigue recibiendo
    // toques si nadie los para, y detrás del selector no hay nada que tocar.
    expect(tester.widget<IgnorePointer>(find.byType(IgnorePointer)).ignoring,
        isTrue);
  });

  testWidgets('vuelve sola cuando el selector se cierra', (tester) async {
    await tester.pumpWidget(_host(apartada: true));
    await tester.pumpAndSettle();
    await tester.pumpWidget(_host(apartada: false));
    await tester.pumpAndSettle();

    expect(_opacidad(tester), 1.0);
    expect(_desplazamiento(tester), Offset.zero);
  });

  testWidgets('con movimiento reducido cambia de golpe, sin viaje',
      (tester) async {
    await tester.pumpWidget(_host(apartada: false, sinAnimaciones: true));
    await tester.pump();
    await tester.pumpWidget(_host(apartada: true, sinAnimaciones: true));
    await tester.pump();

    expect(_opacidad(tester), 0.0);
  });
}
