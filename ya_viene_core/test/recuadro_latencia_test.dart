import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

Future<void> _pintar(WidgetTester tester, MedidorLatencia medidor) =>
    tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: RecuadroLatencia(medidor: medidor)),
      ),
    );

void main() {
  testWidgets('sin muestras lo dice en vez de enseñar números vacíos',
      (tester) async {
    await _pintar(tester, MedidorLatencia());
    expect(find.text('sin datos todavía'), findsOneWidget);
    expect(find.textContaining('p50'), findsNothing);
  });

  testWidgets('enseña los dos tramos y el desfase', (tester) async {
    final medidor = MedidorLatencia();
    final ahora = DateTime.now().millisecondsSinceEpoch;
    for (final retraso in [0, 40, 90]) {
      medidor.registrar(
        {
          'busId': 'BUS-1',
          'capturedAt': ahora - 500,
          'emittedAt': ahora - 100,
          'isGhost': false,
        },
        recibidoEn: DateTime.fromMillisecondsSinceEpoch(ahora + retraso),
      );
    }
    await _pintar(tester, medidor);
    expect(find.textContaining('emisión p50 40 ms · p95 90 ms · n 3'),
        findsOneWidget);
    expect(find.textContaining('captura p50 40 ms'), findsOneWidget);
    expect(find.textContaining('desfase 100 ms'), findsOneWidget);
  });

  testWidgets('no se come los toques de lo que tiene debajo', (tester) async {
    var tocado = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              GestureDetector(
                onTap: () => tocado = true,
                child: Container(color: Colors.blue),
              ),
              const Positioned(top: 0, left: 0, child: RecuadroLatencia()),
            ],
          ),
        ),
      ),
    );
    await tester.tapAt(const Offset(20, 20));
    expect(tocado, isTrue);
  });

  testWidgets('se refresca solo y suelta su reloj al salir', (tester) async {
    final medidor = MedidorLatencia();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RecuadroLatencia(
            medidor: medidor,
            cada: const Duration(milliseconds: 50),
          ),
        ),
      ),
    );
    expect(find.text('sin datos todavía'), findsOneWidget);
    medidor.registrar({'busId': 'BUS-1', 'emittedAt': 1});
    await tester.pump(const Duration(milliseconds: 60));
    expect(find.text('sin datos todavía'), findsNothing);
    // Sin el `cancel` del reloj, el test se queja de un timer pendiente.
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
  });
}
