// En el iPhone se vuelve atrás deslizando desde el borde izquierdo, como en
// todas las apps. La transición propia de la app lo había quitado: el gesto
// vive en la transición de Cupertino (dueño, 2026-10-07).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_pasajero/core/router/app_transitions.dart';

void main() {
  Future<void> abrirSegunda(
      WidgetTester tester, TargetPlatform plataforma) async {
    final navegador = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navegador,
        theme: ThemeData(
          platform: plataforma,
          pageTransitionsTheme: transicionesApp,
        ),
        home: const Scaffold(body: Text('Mapa')),
      ),
    );
    navegador.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Notificaciones')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Notificaciones'), findsOneWidget);
  }

  testWidgets('en el iPhone, deslizar desde el borde izquierdo vuelve atrás',
      (tester) async {
    await abrirSegunda(tester, TargetPlatform.iOS);
    await tester.dragFrom(const Offset(5, 300), const Offset(500, 0));
    await tester.pumpAndSettle();
    expect(find.text('Notificaciones'), findsNothing);
    expect(find.text('Mapa'), findsOneWidget);
  });

  testWidgets('deslizar desde el centro no vuelve atrás', (tester) async {
    await abrirSegunda(tester, TargetPlatform.iOS);
    await tester.dragFrom(const Offset(300, 300), const Offset(400, 0));
    await tester.pumpAndSettle();
    expect(find.text('Notificaciones'), findsOneWidget);
  });
}
