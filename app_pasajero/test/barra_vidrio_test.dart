import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_pasajero/core/widgets/barra_vidrio.dart';

import 'helpers/barra.dart';

/// La barra del título como la de iOS 26 (dueño, 2026-10-18, con WhatsApp
/// de referencia: «se puede ver perfectamente el texto cuando bajo»): sin
/// lámina; con algo debajo, solo un velo que se desvanece hacia abajo, y
/// los botones en píldoras de vidrio. Con más contraste, opaca.
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
                  padding:
                      EdgeInsets.only(top: MediaQuery.paddingOf(context).top),
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

  testWidgets('en reposo no se ve y con algo debajo es vidrio', (tester) async {
    await tester.pumpWidget(pantalla());
    await tester.pumpAndSettle();

    expect(tester.widget<AppBar>(find.byType(AppBar)).systemOverlayStyle,
        SystemUiOverlayStyle.dark,
        reason: 'la hora en oscuro sobre lo blanco');
    expect(velo(tester), 0, reason: 'en reposo no se ve');
    expect(tester.getRect(find.text('fila 0')).top,
        greaterThanOrEqualTo(tester.getRect(find.byType(AppBar)).bottom),
        reason: 'en reposo la barra no tapa nada');

    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();

    expect(velo(tester), 1);
    // Sin lámina: el velo se desvanece hacia abajo y deja leer lo de
    // debajo; nada de desenfoque ni sombra de barra.
    final cara = vidrio(tester);
    expect(cara.color, isNull);
    expect(cara.boxShadow, isNull);
    final degradado = cara.gradient! as LinearGradient;
    expect(degradado.colors.last.a, 0, reason: 'abajo no tapa');
    expect(degradado.colors.first.a, lessThanOrEqualTo(0.9));
    expect(desenfoca(tester), isFalse);
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
    expect(velo(tester), 0);
  });

  testWidgets('con más contraste es opaca y sin desenfoque', (tester) async {
    await tester.pumpWidget(pantalla(contraste: true));
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();

    expect(velo(tester), 1);
    expect(vidrio(tester).color, Colors.white);
    expect(vidrio(tester).gradient, isNull);
  });

  Widget conPildora({bool contraste = false}) => MediaQuery(
        data: MediaQueryData(highContrast: contraste),
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: PildoraVidrio(
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_outlined),
                  onPressed: () {},
                ),
              ),
            ),
          ),
        ),
      );

  testWidgets('la píldora es vidrio: desenfoca, se recorta y flota',
      (tester) async {
    await tester.pumpWidget(conPildora());
    final filtro = find.descendant(
        of: find.byType(PildoraVidrio), matching: find.byType(BackdropFilter));
    expect(filtro, findsOneWidget);
    expect(find.ancestor(of: filtro, matching: find.byType(ClipRRect)),
        findsOneWidget,
        reason: 'sin recorte el desenfoque se come la pantalla');
    final cara = tester
        .widget<DecoratedBox>(find.descendant(
            of: find.byType(PildoraVidrio),
            matching: find.byKey(PildoraVidrio.caraKey)))
        .decoration as BoxDecoration;
    expect(cara.color!.a, inExclusiveRange(0, 1), reason: 'deja ver detrás');
    // La sombra va por fuera del recorte, si no el recorte se la come.
    expect(
        find.ancestor(
            of: find.byType(ClipRRect),
            matching: find.byWidgetPredicate((w) =>
                w is DecoratedBox &&
                (w.decoration as BoxDecoration).boxShadow ==
                    PildoraVidrio.sombra)),
        findsOneWidget);
    // Alto mínimo táctil de 44 (HIG).
    expect(tester.getSize(find.byType(PildoraVidrio)).height,
        greaterThanOrEqualTo(44));
  });

  testWidgets('con más contraste la píldora es opaca y sin desenfoque',
      (tester) async {
    await tester.pumpWidget(conPildora(contraste: true));
    expect(
        find.descendant(
            of: find.byType(PildoraVidrio),
            matching: find.byType(BackdropFilter)),
        findsNothing);
    final cara = tester
        .widget<DecoratedBox>(find.byKey(PildoraVidrio.caraKey))
        .decoration as BoxDecoration;
    expect(cara.color, Colors.white);
  });
}
