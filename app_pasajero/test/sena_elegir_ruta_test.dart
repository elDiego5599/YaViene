import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_pasajero/features/map/presentation/widgets/sena_elegir_ruta.dart';

/// Las fichas en abanico del estado «Escoge empresa y ruta».
void main() {
  Future<void> montar(WidgetTester tester, {bool reducido = false}) =>
      tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(disableAnimations: reducido),
          child: const Center(child: SenaElegirRuta()),
        ),
      );

  testWidgets('escoge, descansa sin pintar cuadros y vuelve a escoger',
      (tester) async {
    const toque = SenaElegirRuta.toque;
    const pausa = SenaElegirRuta.pausa;
    await montar(tester);
    await tester.pump(toque ~/ 2);
    expect(tester.binding.hasScheduledFrame, isTrue);
    await tester.pump(toque ~/ 2 + const Duration(milliseconds: 50));
    await tester.pump(pausa ~/ 2);
    expect(tester.binding.hasScheduledFrame, isFalse,
        reason: 'en la pausa el mapa de atrás no se recompone');
    await tester.pump(pausa ~/ 2 + toque ~/ 4);
    expect(tester.binding.hasScheduledFrame, isTrue);
  });

  testWidgets('con el movimiento reducido se queda quieta', (tester) async {
    await montar(tester, reducido: true);
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  test('la ficha del frente salta como el pin y vuelve a su sitio', () {
    expect(SenaElegirRuta.alzada(0), 0);
    expect(SenaElegirRuta.alzada(1), 0);
    expect(SenaElegirRuta.alzada(0.22), closeTo(1, 1e-9));
    for (var i = 1; i <= 84; i++) {
      final antes = SenaElegirRuta.alzada((i - 1) / 84);
      final ahora = SenaElegirRuta.alzada(i / 84);
      expect((ahora - antes).abs(), lessThan(0.2), reason: 'cuadro $i');
    }
  });

  test('las de atrás se abren y vuelven sin pasarse', () {
    expect(SenaElegirRuta.apertura(0), 0);
    expect(SenaElegirRuta.apertura(1), 0);
    expect(SenaElegirRuta.apertura(0.26), closeTo(1, 1e-9));
    for (var i = 0; i <= 100; i++) {
      final a = SenaElegirRuta.apertura(i / 100);
      expect(a, inInclusiveRange(0, 1), reason: 't = ${i / 100}');
    }
    for (var i = 1; i <= 84; i++) {
      final antes = SenaElegirRuta.apertura((i - 1) / 84);
      final ahora = SenaElegirRuta.apertura(i / 84);
      expect((ahora - antes).abs(), lessThan(0.15), reason: 'cuadro $i');
    }
  });

  test('el chulito brota al caer, se queda y se va antes del descanso', () {
    // Mientras sube no hay chulito: aún no ha escogido.
    for (final t in [0.0, 0.1, 0.22, 0.4]) {
      expect(SenaElegirRuta.marca(t).opacidad, 0, reason: 't = $t');
    }
    expect(SenaElegirRuta.marca(0.75), (escala: 1.0, opacidad: 1.0));
    // El descanso es la pose del arranque: sin chulito.
    expect(SenaElegirRuta.marca(1).opacidad, 0);
    // Al brotar se pasa un poquito, lo del resorte, y nunca un 5 %.
    final mayor = [
      for (var i = 40; i <= 70; i++) SenaElegirRuta.marca(i / 100).escala
    ].reduce((a, b) => a > b ? a : b);
    expect(mayor, greaterThan(1));
    expect(mayor, lessThan(1.05));
  });
}
