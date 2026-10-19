import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_pasajero/core/widgets/barra_vidrio.dart';

/// La cara de la barra de vidrio: su velo o, con más contraste, su blanco.
BoxDecoration vidrio(WidgetTester tester) => tester
    .widget<DecoratedBox>(find.descendant(
        of: find.byType(FondoVidrio), matching: find.byType(DecoratedBox)))
    .decoration as BoxDecoration;

/// Las capas de desenfoque de la barra, de la más alta a la más baja.
List<Rect> capasDesenfoque(WidgetTester tester) {
  final filtros = find.descendant(
      of: find.byType(FondoVidrio), matching: find.byType(BackdropFilter));
  return [
    for (final e in filtros.evaluate())
      if ((e.widget as BackdropFilter).enabled)
        tester.getRect(find.byWidget(e.widget)),
  ]..sort((a, b) => b.height.compareTo(a.height));
}

/// Si la barra desenfoca lo que pasa debajo.
bool desenfoca(WidgetTester tester) => capasDesenfoque(tester).isNotEmpty;

/// La pantalla lleva la barra de vidrio y lo de abajo pasa por debajo de
/// ella (dueño, 2026-10-18: «como el nav de la web»): en reposo [primero]
/// queda entero bajo la barra y sin vidrio, y al bajar algo se mete detrás
/// y el vidrio sale (dueño, 2026-10-19).
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
  expect(desenfoca(tester), isFalse, reason: 'en reposo no hay vidrio');

  final antes = tester.getRect(primero).top;
  await tester.drag(find.byType(Scrollable).first, const Offset(0, -40));
  await tester.pumpAndSettle();
  expect(tester.getRect(primero).top, lessThan(antes),
      reason: 'lo de abajo no se desplaza');
  expect(tester.getRect(primero).top, lessThan(barra.bottom),
      reason: 'lo de abajo no pasa por debajo de la barra');
  expect(desenfoca(tester), isTrue, reason: 'al bajar sale el vidrio');
}
