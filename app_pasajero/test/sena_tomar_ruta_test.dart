import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_pasajero/features/map/presentation/widgets/sena_tomar_ruta.dart';

/// El pin que salta a la ruta del estado «Toca el mapa donde tomas tu bus».
void main() {
  Future<void> montar(WidgetTester tester, {bool reducido = false}) =>
      tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(disableAnimations: reducido),
          child: const Center(child: SenaTomarRuta()),
        ),
      );

  testWidgets('salta, descansa sin pintar cuadros y vuelve a saltar',
      (tester) async {
    const salto = SenaTomarRuta.salto;
    const pausa = SenaTomarRuta.pausa;
    await montar(tester);
    await tester.pump(salto ~/ 2);
    expect(tester.binding.hasScheduledFrame, isTrue);
    await tester.pump(salto ~/ 2 + const Duration(milliseconds: 50));
    await tester.pump(pausa ~/ 2);
    expect(tester.binding.hasScheduledFrame, isFalse,
        reason: 'en la pausa el mapa de atrás no se recompone');
    await tester.pump(pausa ~/ 2 + salto ~/ 4);
    expect(tester.binding.hasScheduledFrame, isTrue);
  });

  testWidgets('con el movimiento reducido se queda quieta', (tester) async {
    await montar(tester, reducido: true);
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  test('el pin despega y se posa sin brincos', () {
    expect(SenaTomarRuta.alzada(0), 0);
    expect(SenaTomarRuta.alzada(1), 0);
    expect(SenaTomarRuta.alzada(0.22), closeTo(1, 1e-9));
    // Sube y baja sin saltos de un cuadro a otro (60 Hz sobre 1,4 s).
    for (var i = 1; i <= 84; i++) {
      final antes = SenaTomarRuta.alzada((i - 1) / 84);
      final ahora = SenaTomarRuta.alzada(i / 84);
      expect((ahora - antes).abs(), lessThan(0.2), reason: 'cuadro $i');
    }
    // Al posarse se hunde un poquito, lo que se pasa el resorte, y nada más.
    final hundido = [
      for (var i = 0; i <= 100; i++) SenaTomarRuta.alzada(i / 100)
    ].reduce((a, b) => a < b ? a : b);
    expect(hundido, lessThan(0));
    expect(hundido, greaterThan(-0.06));
  });

  test('el anillo nace al posarse, crece y se apaga', () {
    expect(SenaTomarRuta.anillo(0.3).opacidad, 0);
    expect(SenaTomarRuta.anillo(1).opacidad, 0);
    expect(SenaTomarRuta.anillo(0.5).opacidad, greaterThan(0));
    expect(SenaTomarRuta.anillo(0.9).radio,
        greaterThan(SenaTomarRuta.anillo(0.5).radio));
    expect(SenaTomarRuta.anillo(1).radio, lessThanOrEqualTo(0.26));
  });
}
