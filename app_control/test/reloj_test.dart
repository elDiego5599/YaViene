// El reloj de la barra del panel.
//
// Cambiaba con un `Timer.periodic` de un segundo armado cuando se abría el
// panel: si se abría a las 10:00:00,700, el «10:00:01» salía a las
// 10:00:01,700, siempre hasta un segundo tarde frente al reloj del equipo, y
// el temporizador además se corría con el tiempo. Un panel de flota que
// muestra la hora tiene que mostrar la hora. Ahora cada latido cae en el
// cambio de segundo.
//
// Y repinta solo: cada segundo pintaba de nuevo la barra entera y lo que
// comparte capa con ella.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_control/shared/widgets/clock_widget.dart';

void main() {
  late DateTime ahora;

  Future<void> montar(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: ClockWidget(reloj: () => ahora)),
    ),
  );

  testWidgets('el segundo cambia cuando cambia el del equipo, no después', (
    tester,
  ) async {
    ahora = DateTime(2026, 9, 27, 10, 0, 0, 700);
    await montar(tester);
    expect(find.text('10:00:00'), findsOneWidget);

    ahora = DateTime(2026, 9, 27, 10, 0, 1, 0);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('10:00:01'), findsOneWidget);

    // Y no se corre: el siguiente latido cae otra vez en el cambio.
    ahora = DateTime(2026, 9, 27, 10, 0, 2, 0);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('10:00:02'), findsOneWidget);
  });

  testWidgets('pinta en su propia capa', (tester) async {
    ahora = DateTime(2026, 9, 27, 10);
    await montar(tester);
    expect(
      find.descendant(
        of: find.byType(ClockWidget),
        matching: find.byType(RepaintBoundary),
      ),
      findsOneWidget,
    );
  });

  testWidgets('al cerrarse no deja latidos pendientes', (tester) async {
    ahora = DateTime(2026, 9, 27, 10, 0, 0, 400);
    await montar(tester);
    await tester.pumpWidget(const SizedBox());
    // Si quedara un temporizador vivo, la prueba falla al terminar.
    await tester.pump(const Duration(seconds: 2));
  });
}
