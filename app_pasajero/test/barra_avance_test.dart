// La barra de avance de la hoja (dueño, 2026-10-19, como Flighty): una
// línea de tu punto al bus, con el bus deslizándose hacia ti.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_pasajero/features/map/presentation/widgets/barra_avance.dart';

const _ancho = 300.0;
const _color = Color(0xFF4338CA);

Future<void> _montar(WidgetTester tester, double metros,
        {double? aviso, bool reducido = false}) =>
    tester.pumpWidget(MediaQuery(
      data: MediaQueryData(disableAnimations: reducido),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            width: _ancho,
            child: BarraAvance(metros: metros, color: _color, aviso: aviso),
          ),
        ),
      ),
    ));

double _x(WidgetTester tester, String key) {
  final barra = tester.getRect(find.byType(BarraAvance));
  return tester.getCenter(find.byKey(ValueKey(key))).dx - barra.left;
}

void main() {
  test('el avance: 3 km o más es el arranque, 0 m es tu punto', () {
    expect(BarraAvance.avance(3000), 0);
    expect(BarraAvance.avance(5000), 0);
    expect(BarraAvance.avance(1500), 0.5);
    expect(BarraAvance.avance(0), 1);
    expect(BarraAvance.avance(-5), 1);
  });

  testWidgets('el bus va donde está, y tu punto al final', (tester) async {
    await _montar(tester, 1500);
    await tester.pumpAndSettle();
    final carril = BarraAvance.carril(_ancho);
    expect(_x(tester, 'barra-bus'),
        closeTo(carril.izquierda + carril.largo / 2, 0.5));
    expect(_x(tester, 'barra-punto'),
        closeTo(carril.izquierda + carril.largo, 0.5));
  });

  testWidgets('se desliza al acercarse, sin saltar', (tester) async {
    await _montar(tester, 3000);
    await tester.pumpAndSettle();
    final antes = _x(tester, 'barra-bus');
    await _montar(tester, 0);
    await tester.pump(const Duration(milliseconds: 60));
    final enMedio = _x(tester, 'barra-bus');
    await tester.pumpAndSettle();
    final despues = _x(tester, 'barra-bus');
    expect(enMedio, greaterThan(antes));
    expect(enMedio, lessThan(despues));
  });

  testWidgets('con el movimiento reducido llega sin deslizarse',
      (tester) async {
    await _montar(tester, 3000, reducido: true);
    await _montar(tester, 0, reducido: true);
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('la marca del aviso solo con el aviso puesto, en su distancia',
      (tester) async {
    await _montar(tester, 2000);
    expect(find.byKey(const ValueKey('barra-aviso')), findsNothing);
    await _montar(tester, 2000, aviso: 1000);
    await tester.pumpAndSettle();
    final carril = BarraAvance.carril(_ancho);
    expect(
        _x(tester, 'barra-aviso'),
        closeTo(
            carril.izquierda + carril.largo * BarraAvance.avance(1000), 0.5));
  });

  testWidgets('no se lee: la cifra ya dice la distancia', (tester) async {
    final semantica = tester.ensureSemantics();
    await _montar(tester, 1500);
    expect(find.bySemanticsLabel(RegExp('.')), findsNothing);
    semantica.dispose();
  });
}
