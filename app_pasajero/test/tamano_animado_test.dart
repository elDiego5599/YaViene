import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import 'package:ya_viene_pasajero/core/widgets/tamano_animado.dart';

/// Con «Reducir movimiento», `AnimatedSize` a duración cero se rompe: su
/// controlador termina en el mismo layout que lo arrancó y vuelve a
/// ensuciar el render mientras se mide. La hoja del mapa lo hacía cada vez
/// que cambiaba de alto.
void main() {
  Future<void Function()> montar(WidgetTester tester,
      {required bool reducido}) async {
    late StateSetter cambiar;
    var alto = 40.0;
    await tester.pumpWidget(MediaQuery(
      data: MediaQueryData(disableAnimations: reducido),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topCenter,
          child: StatefulBuilder(builder: (context, setState) {
            cambiar = setState;
            return TamanoAnimado(
              duracion: AppMotion.pausado,
              child: SizedBox(key: const ValueKey('hijo'), height: alto),
            );
          }),
        ),
      ),
    ));
    return () => cambiar(() => alto = 120);
  }

  double alto(WidgetTester tester) =>
      tester.getSize(find.byType(TamanoAnimado)).height;

  testWidgets('con menos movimiento salta al tamaño nuevo sin romperse',
      (tester) async {
    final crecer = await montar(tester, reducido: true);

    crecer();
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(alto(tester), 120);
  });

  testWidgets('con movimiento, crece de a poco', (tester) async {
    final crecer = await montar(tester, reducido: false);

    crecer();
    await tester.pump();
    await tester.pump(AppMotion.pausado ~/ 2);
    expect(alto(tester), inExclusiveRange(40, 120));
    await tester.pumpAndSettle();
    expect(alto(tester), 120);
  });

  test('nadie usa AnimatedSize suelto en la app', () {
    final sueltos = [
      for (final f in Directory('lib').listSync(recursive: true))
        if (f is File &&
            f.path.endsWith('.dart') &&
            !f.path.endsWith('tamano_animado.dart') &&
            f.readAsStringSync().contains('AnimatedSize('))
          f.path,
    ];
    expect(sueltos, isEmpty, reason: 'va por TamanoAnimado');
  });
}
