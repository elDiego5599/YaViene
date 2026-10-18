import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_pasajero/core/widgets/barra_vidrio.dart';

import 'helpers/barra.dart';

/// La barra del título como el nav de la web (dueño, 2026-10-18: «que se
/// pueda ver el texto a través de él cuando uno baja, excepto obviamente el
/// título»): en reposo no se ve; con algo debajo, blanco al 82 % con
/// desenfoque, su filo y su sombra suave. Con más contraste, opaca.
void main() {
  Widget pantalla({bool contraste = false}) => MediaQuery(
        data: MediaQueryData(
          size: const Size(390, 844),
          padding: const EdgeInsets.only(top: 47),
          highContrast: contraste,
        ),
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              extendBodyBehindAppBar: true,
              appBar: barraVidrio(title: const Text('Título')),
              body: Builder(
                builder: (context) => ListView(
                  padding: EdgeInsets.only(
                      top: MediaQuery.paddingOf(context).top),
                  children: [
                    for (var i = 0; i < 40; i++)
                      SizedBox(height: 40, child: Text('fila $i')),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

  testWidgets('en reposo no se ve y con algo debajo es vidrio',
      (tester) async {
    await tester.pumpWidget(pantalla());
    await tester.pumpAndSettle();

    expect(tester.widget<AppBar>(find.byType(AppBar)).systemOverlayStyle,
        SystemUiOverlayStyle.dark,
        reason: 'la hora en oscuro sobre lo blanco');
    expect(vidrio(tester).color!.a, 0, reason: 'en reposo no se ve');
    expect(vidrio(tester).boxShadow, isEmpty);
    expect(desenfoca(tester), isFalse);
    expect(tester.getRect(find.text('fila 0')).top,
        greaterThanOrEqualTo(tester.getRect(find.byType(AppBar)).bottom),
        reason: 'en reposo la barra no tapa nada');

    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();

    expect(vidrio(tester).color, Colors.white.withValues(alpha: 0.82));
    expect(vidrio(tester).boxShadow, FondoVidrio.sombra);
    expect(desenfoca(tester), isTrue);
    // Lo de abajo pasa por debajo de la barra, y el título sigue entero.
    final barra = tester.getRect(find.byType(AppBar));
    expect(
        find.byWidgetPredicate((w) =>
            w is Text &&
            (w.data ?? '').startsWith('fila') &&
            tester.getRect(find.byWidget(w)).overlaps(barra)),
        findsWidgets);
    final titulo = tester.renderObject<RenderParagraph>(find.text('Título'));
    expect(titulo.text.style!.color!.a, 1);

    // De vuelta arriba se apaga otra vez.
    await tester.drag(find.byType(ListView), const Offset(0, 600));
    await tester.pumpAndSettle();
    expect(vidrio(tester).color!.a, 0);
    expect(desenfoca(tester), isFalse);
  });

  testWidgets('con más contraste es opaca y sin desenfoque', (tester) async {
    await tester.pumpWidget(pantalla(contraste: true));
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();

    expect(vidrio(tester).color, Colors.white);
    expect(desenfoca(tester), isFalse);
  });
}
