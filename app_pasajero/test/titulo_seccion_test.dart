import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import 'package:ya_viene_pasajero/core/widgets/titulo_seccion.dart';

/// «Siento que en las páginas deberíamos incluir separaciones entre títulos
/// y cosas así para que se vea más prolijo» (dueño, 2026-10-18, con Salud
/// del iPhone de referencia): cada grupo lleva su título en negrita, fuera
/// de la tarjeta, con aire arriba para que se lea como otro bloque.
void main() {
  Future<void> montar(WidgetTester tester, {bool primero = false}) =>
      tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(key: ValueKey('antes'), height: 10),
              TituloSeccion('Esperando', primero: primero),
              const SizedBox(key: ValueKey('despues'), height: 10),
            ],
          ),
        ),
      ));

  testWidgets('en negrita, en tinta y anunciado como encabezado',
      (tester) async {
    final semantica = tester.ensureSemantics();
    await montar(tester);
    final estilo = tester.widget<Text>(find.text('Esperando')).style!;
    expect(estilo.fontSize, AppTextStyles.titulo.fontSize);
    expect(estilo.fontWeight, FontWeight.w700);
    expect(estilo.color, AppColors.textPrimary);
    expect(tester.getSemantics(find.text('Esperando')),
        isSemantics(label: 'Esperando', isHeader: true));
    semantica.dispose();
  });

  testWidgets('28 de aire arriba (12 si es el primero) y 10 hasta su grupo',
      (tester) async {
    double arriba() =>
        tester.getTopLeft(find.text('Esperando')).dy -
        tester.getBottomLeft(find.byKey(const ValueKey('antes'))).dy;
    double abajo() =>
        tester.getTopLeft(find.byKey(const ValueKey('despues'))).dy -
        tester.getBottomLeft(find.text('Esperando')).dy;

    await montar(tester);
    expect(arriba(), 28);
    expect(abajo(), 10);
    await montar(tester, primero: true);
    expect(arriba(), 12);
    // A ras del texto de las tarjetas, no de su filo: 4 hacia adentro.
    expect(tester.getTopLeft(find.text('Esperando')).dx, 4);
  });
}
