import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_pasajero/core/widgets/borde_desvanecido.dart';

/// Lo que sube se disuelve bajo el título en vez de esconderse en seco tras
/// la barra (dueño, 2026-10-16: «como en la foto»): el desplazable va dentro
/// del [BordeDesvanecido], la barra no se oscurece al pasarle algo debajo y,
/// en reposo, [primero] queda entero, por debajo de la franja que se funde.
void exigeBordeDesvanecido(WidgetTester tester, Finder primero) {
  final borde = find.byType(BordeDesvanecido);
  expect(borde, findsOneWidget);
  expect(find.descendant(of: borde, matching: find.byType(Scrollable)),
      findsWidgets);
  expect(tester.widget<AppBar>(find.byType(AppBar)).scrolledUnderElevation, 0);
  expect(tester.getRect(primero).top - tester.getRect(borde).top,
      greaterThanOrEqualTo(BordeDesvanecido.alto));
}
