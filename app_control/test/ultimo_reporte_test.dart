// La ficha del bus seleccionado decía su estado —«En línea», «Inactivo»—
// pero no cuándo se supo de él. Para una empresa, «En línea» sin hora es
// una promesa; «Último reporte ahora» es un dato. (La velocidad iba aquí
// detrás; ahora tiene su cifra propia en la ficha: velocidad_bus_test.dart.) Si el bus se
// calla, la cuenta sube sola: el operador ve que se calló antes de que el
// servidor lo marque inactivo a los 90 s.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_control/features/fleet/presentation/widgets/ultimo_reporte.dart';

void main() {
  late DateTime ahora;
  final base = DateTime(2026, 9, 27, 10);
  int ms(Duration antes) => base.subtract(antes).millisecondsSinceEpoch;

  Future<void> montar(
    WidgetTester tester, {
    required int? reportadoEn,
  }) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: UltimoReporte(
          reportadoEn: reportadoEn,
          reloj: () => ahora,
        ),
      ),
    ),
  );

  setUp(() => ahora = base);

  testWidgets('un bus que acaba de reportar: «ahora»', (tester) async {
    await montar(tester, reportadoEn: ms(const Duration(milliseconds: 800)));
    expect(find.text('Último reporte ahora'), findsOneWidget);
  });

  testWidgets('en segundos, minutos, horas y días', (tester) async {
    for (final (antes, texto) in [
      (const Duration(seconds: 7), 'Último reporte hace 7 s'),
      (const Duration(minutes: 2, seconds: 30), 'Último reporte hace 2 min'),
      (const Duration(hours: 3, minutes: 10), 'Último reporte hace 3 h'),
      (const Duration(days: 2, hours: 5), 'Último reporte hace 2 d'),
    ]) {
      await montar(tester, reportadoEn: ms(antes));
      expect(find.text(texto), findsOneWidget, reason: texto);
    }
  });

  testWidgets(
    'un reloj del servidor un poco adelantado no da tiempo negativo',
    (tester) async {
      await montar(tester, reportadoEn: ms(const Duration(seconds: -3)));
      expect(find.text('Último reporte ahora'), findsOneWidget);
    },
  );

  testWidgets('sin reportes lo dice, y no cuenta', (tester) async {
    await montar(tester, reportadoEn: null);
    expect(find.text('Sin reportes todavía'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Sin reportes todavía'), findsOneWidget);
  });

  testWidgets('si el bus se calla, la cuenta sube sola', (tester) async {
    await montar(tester, reportadoEn: ms(Duration.zero));
    expect(find.text('Último reporte ahora'), findsOneWidget);
    ahora = base.add(const Duration(seconds: 4));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Último reporte hace 4 s'), findsOneWidget);
  });

  testWidgets('pinta en su propia capa y no deja latidos al cerrarse', (
    tester,
  ) async {
    await montar(tester, reportadoEn: ms(Duration.zero));
    expect(
      find.descendant(
        of: find.byType(UltimoReporte),
        matching: find.byType(RepaintBoundary),
      ),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
  });
}
