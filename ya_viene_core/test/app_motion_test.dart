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
}
