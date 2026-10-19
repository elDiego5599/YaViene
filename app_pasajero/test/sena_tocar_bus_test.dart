import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import 'package:ya_viene_pasajero/features/map/presentation/widgets/sena_tocar_bus.dart';

/// El bus con su toque del estado «Toca un bus en el mapa».
void main() {
  Future<void> montar(WidgetTester tester, {bool reducido = false}) =>
      tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(disableAnimations: reducido),
          child: const Center(child: SenaTocarBus(color: AppColors.acento)),
        ),
      );

  testWidgets('toca, descansa sin pintar cuadros y vuelve a tocar',
      (tester) async {
    const toque = SenaTocarBus.toque;
    const pausa = SenaTocarBus.pausa;
    await montar(tester);
    await tester.pump(toque ~/ 2);
    expect(tester.binding.hasScheduledFrame, isTrue,
        reason: 'a mitad del toque los anillos siguen saliendo');
    await tester.pump(toque ~/ 2 + const Duration(milliseconds: 50));
    await tester.pump(pausa ~/ 2);
    // En la pausa, la hoja no pide cuadros: el mapa de atrás no se
    // recompone por un dibujo quieto.
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.pump(pausa ~/ 2 + toque ~/ 4);
    expect(tester.binding.hasScheduledFrame, isTrue,
        reason: 'tras la pausa vuelve a tocar');
  });

  testWidgets('con el movimiento reducido se queda quieta', (tester) async {
    await montar(tester, reducido: true);
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  test('el toque: el bus se hunde y vuelve, y los anillos se apagan', () {
    // Al empezar y al terminar el bus está a su tamaño y no hay anillo.
    expect(SenaTocarBus.escalaBus(0), 1);
    expect(SenaTocarBus.escalaBus(1), closeTo(1, 1e-9));
    expect(SenaTocarBus.anillo(1, 0).opacidad, 0);
    expect(SenaTocarBus.anillo(1, 1).opacidad, 0);
    // A mitad del hundido el bus es más chico, sin pasar del 90 %.
    final hundido = SenaTocarBus.escalaBus(0.1);
    expect(hundido, lessThan(1));
    expect(hundido, greaterThanOrEqualTo(0.9));
    // Los anillos crecen hacia afuera sin salirse del medallón.
    var radio = 0.0;
    for (var i = 1; i < 20; i++) {
      final a = SenaTocarBus.anillo(1, i / 20);
      expect(a.radio, greaterThanOrEqualTo(radio));
      expect(a.radio, lessThanOrEqualTo(0.5));
      radio = a.radio;
    }
    // El eco sale después que el primero.
    expect(SenaTocarBus.anillo(2, 0.1).opacidad, 0);
    expect(SenaTocarBus.anillo(1, 0.2).opacidad, greaterThan(0));
  });
}
