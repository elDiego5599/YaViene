import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_pasajero/core/widgets/barra_vidrio.dart';

/// La cara de la barra de vidrio: su color y su sombra de ahora.
BoxDecoration vidrio(WidgetTester tester) => tester
    .widget<AnimatedContainer>(find.descendant(
        of: find.byType(FondoVidrio), matching: find.byType(AnimatedContainer)))
    .decoration! as BoxDecoration;

/// Si la barra desenfoca lo que pasa debajo.
bool desenfoca(WidgetTester tester) {
  final filtro = find.descendant(
      of: find.byType(FondoVidrio), matching: find.byType(BackdropFilter));
  return filtro.evaluate().isNotEmpty &&
      tester.widget<BackdropFilter>(filtro).enabled;
}

/// La pantalla lleva la barra de vidrio y lo de abajo pasa por debajo de
/// ella (dueño, 2026-10-18: «como el nav de la web»): en reposo [primero]
/// queda entero bajo la barra, y al bajar algo se mete detrás de ella y la
/// barra se vuelve vidrio.
Future<void> exigeBarraVidrio(WidgetTester tester, Finder primero) async {
  expect(find.byType(FondoVidrio), findsOneWidget);
  expect(
      tester
          .widget<Scaffold>(find.byType(Scaffold).first)
          .extendBodyBehindAppBar,
      isTrue,
      reason: 'lo de abajo no pasa por debajo de la barra');
  final barra = tester.getRect(find.byType(AppBar));
  expect(tester.getRect(primero).top, greaterThanOrEqualTo(barra.bottom - 0.5),
      reason: 'en reposo la barra tapa lo primero');
  expect(vidrio(tester).color!.a, 0);

  final antes = tester.getRect(primero).top;
  await tester.drag(find.byType(Scrollable).first, const Offset(0, -40));
  await tester.pumpAndSettle();
  expect(tester.getRect(primero).top, lessThan(antes),
      reason: 'lo de abajo no se desplaza');
  expect(tester.getRect(primero).top, lessThan(barra.bottom),
      reason: 'lo de abajo no pasa por debajo de la barra');
  expect(vidrio(tester).color!.a, greaterThan(0));
}
