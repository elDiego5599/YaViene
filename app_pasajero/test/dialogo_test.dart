import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import 'package:ya_viene_pasajero/core/widgets/dialogo.dart';

void main() {
  Future<Future<bool?> Function()> abrir(WidgetTester tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Builder(builder: (c) {
          ctx = c;
          return const Scaffold();
        }),
      ),
    );
    return () => mostrarDialogo<bool>(
          ctx,
          (d) => Dialogo(
            icono: Icons.restart_alt_rounded,
            titulo: '¿Reiniciar la guía?',
            mensaje: 'Vas a perder la ruta.',
            delicado: true,
            principal: DialogoAccion('Reiniciar guía', () {
              Navigator.pop(d, true);
            }),
            secundaria: DialogoAccion('Cancelar', () {
              Navigator.pop(d, false);
            }),
          ),
        );
  }

  testWidgets('el botón principal va encima y a todo el ancho', (tester) async {
    final abre = await abrir(tester);
    final resultado = abre();
    await tester.pumpAndSettle();

    // Nada del AlertDialog de fábrica: es la ventana propia de la app.
    expect(find.byType(AlertDialog), findsNothing);
    final principal = tester.getRect(find.text('Reiniciar guía'));
    final secundaria = tester.getRect(find.text('Cancelar'));
    expect(principal.center.dy, lessThan(secundaria.center.dy));
    final boton = tester.getRect(find.byType(FilledButton));
    final ventana = tester.getRect(find
        .descendant(of: find.byType(Dialogo), matching: find.byType(Material))
        .first);
    // 20 de relleno a cada lado y el filo de 1.
    expect(boton.width, closeTo(ventana.width - 40 - 2, 1));

    await tester.tap(find.text('Reiniciar guía'));
    await tester.pumpAndSettle();
    expect(await resultado, isTrue);
  });

  testWidgets('tocar fuera cierra sin aceptar', (tester) async {
    final abre = await abrir(tester);
    final resultado = abre();
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.byType(Dialogo), findsNothing);
    expect(await resultado, isNull);
  });
}
