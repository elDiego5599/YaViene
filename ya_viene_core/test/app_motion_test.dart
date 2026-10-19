import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

Widget _conAjuste({required bool sinAnimaciones, required Widget hijo}) {
  return MediaQuery(
    data: MediaQueryData(disableAnimations: sinAnimaciones),
    child: Directionality(textDirection: TextDirection.ltr, child: hijo),
  );
}

void main() {
  testWidgets('sin el ajuste puesto, el movimiento va entero', (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(_conAjuste(
      sinAnimaciones: false,
      hijo: Builder(builder: (context) {
        ctx = context;
        return const SizedBox();
      }),
    ));

    expect(AppMotion.reducido(ctx), isFalse);
    expect(AppMotion.desplazamiento(ctx), 1.0);
    expect(
      AppMotion.duracion(ctx, const Duration(milliseconds: 300)),
      const Duration(milliseconds: 300),
    );
  });

  testWidgets('con el ajuste puesto, no queda desplazamiento ni duración',
      (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(_conAjuste(
      sinAnimaciones: true,
      hijo: Builder(builder: (context) {
        ctx = context;
        return const SizedBox();
      }),
    ));

    expect(AppMotion.reducido(ctx), isTrue);
    expect(AppMotion.desplazamiento(ctx), 0.0);
    expect(
      AppMotion.duracion(ctx, const Duration(milliseconds: 300)),
      Duration.zero,
    );
  });

  group('resorte', () {
    List<double> muestras(Curve c) =>
        [for (var i = 0; i <= 200; i++) c.transform(i / 200)];

    test('amortiguado del todo: sube sin pasarse y arranca quieto', () {
      final v = muestras(const Resorte());
      for (var i = 1; i < v.length; i++) {
        expect(v[i], greaterThanOrEqualTo(v[i - 1]));
        expect(v[i], lessThanOrEqualTo(1));
      }
      // Arranca desde el reposo, sin el tirón de una curva que sale
      // disparada: el primer 1 % recorre menos del 1 %.
      expect(v[2], lessThan(0.01));
      // Y a la mitad ya casi llegó: lo que queda es la frenada.
      expect(v[100], greaterThan(0.9));
      // Sin salto al final.
      expect(1 - v[199], lessThan(0.002));
    });

    test('con rebote: se pasa poco y vuelve', () {
      final v = muestras(const Resorte(amortiguacion: 0.7));
      final pico = v.reduce((a, b) => a > b ? a : b);
      expect(pico, greaterThan(1.02));
      expect(pico, lessThan(1.06));
      expect((1 - v[199]).abs(), lessThan(0.002));
    });

    test('las curvas de entrada y de cambio son el resorte', () {
      expect(AppMotion.curvaEntrada, isA<Resorte>());
      expect(AppMotion.curvaCambio, isA<Resorte>());
      expect(AppMotion.curvaRebote, isA<Resorte>());
    });
  });
}
