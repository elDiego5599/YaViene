import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_pasajero/core/widgets/barra_vidrio.dart';

import 'helpers/barra.dart';

/// La barra del título como la de iOS 26 (dueño, 2026-10-18, con WhatsApp
/// de referencia: «se puede ver perfectamente el texto cuando bajo»): sin
/// lámina; con algo debajo, un desenfoque que crece hacia arriba y un velo
/// que se desvanece hacia abajo («las hiciste completamente transparentes
/// en vez de darle como un tipo de blur»), y los botones en píldoras de
/// vidrio. Con más contraste, opaca.
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

  testWidgets('el vidrio sale al bajar, de a poco, y se va al subir',
      (tester) async {
    await tester.pumpWidget(pantalla());
    await tester.pumpAndSettle();

    expect(tester.widget<AppBar>(find.byType(AppBar)).systemOverlayStyle,
        SystemUiOverlayStyle.dark,
        reason: 'la hora en oscuro sobre lo blanco');
    expect(tester.getRect(find.text('fila 0')).top,
        greaterThanOrEqualTo(tester.getRect(find.byType(AppBar)).bottom),
        reason: 'en reposo la barra no tapa nada');
    // En reposo no hay vidrio: solo sale al bajar (dueño, 2026-10-19).
    expect(desenfoca(tester), isFalse);
    expect(FondoVidrio.velo.colors.map((c) => c.a), everyElement(lessThan(1)));
    expect(tester.widget<Opacity>(find.byKey(FondoVidrio.veloKey)).opacity, 0);

    // Sigue al dedo, no a un reloj: a medio camino, a medias, y subir lo
    // devuelve por el mismo camino.
    final lista = tester.state<ScrollableState>(find.byType(Scrollable));
    lista.position.jumpTo(FondoVidrio.recorrido / 2);
    await tester.pump();
    expect(desenfoca(tester), isTrue);
    final medio =
        tester.widget<Opacity>(find.byKey(FondoVidrio.veloKey)).opacity;
    expect(medio, closeTo(0.5, 0.01));
    expect(filtros(tester), [
      for (final (_, sigma) in FondoVidrio.capas)
        ui.ImageFilter.blur(sigmaX: sigma / 2, sigmaY: sigma / 2),
    ]);
    lista.position.jumpTo(300);
    await tester.pump();
    expect(tester.widget<Opacity>(find.byKey(FondoVidrio.veloKey)).opacity, 1);
    expect(filtros(tester), [
      for (final (_, sigma) in FondoVidrio.capas)
        ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
    ]);
    lista.position.jumpTo(0);
    await tester.pump();
    expect(desenfoca(tester), isFalse, reason: 'al subir se va');
    lista.position.jumpTo(300);
    await tester.pump();

    final barra = tester.getRect(find.byType(AppBar));
    // Sin lámina: el velo se desvanece hacia abajo y deja leer lo de
    // debajo; ni sombra de barra.
    final cara = vidrio(tester);
    expect(cara.color, isNull);
    expect(cara.boxShadow, isNull);
    final degradado = cara.gradient! as LinearGradient;
    expect(degradado.colors.last.a, 0, reason: 'abajo no tapa');
    expect(degradado.colors.first.a, lessThanOrEqualTo(0.9));
    // El desenfoque es progresivo, como el borde de iOS 26: capas
    // recortadas que arrancan arriba y bajan cada una menos, así arriba
    // se suman todas y al pie apenas una.
    final capas = capasDesenfoque(tester);
    expect(capas.length, FondoVidrio.capas.length);
    expect(capas.first.height, closeTo(barra.height, 0.5),
        reason: 'la de abajo llega al pie de la barra');
    for (var i = 0; i < capas.length; i++) {
      expect(capas[i].top, closeTo(barra.top, 0.5));
      if (i > 0) expect(capas[i].height, lessThan(capas[i - 1].height));
    }
    // El sigma sumado crece sin escalones de más de un punto, y al pie
    // arranca casi en cero: con 0,8 de golpe se veía la raya recta entre
    // lo desenfocado y lo nítido (dueño, 2026-10-19).
    var antes = 0.0;
    for (var k = 0; k < FondoVidrio.capas.length; k++) {
      final suma = math.sqrt(
          FondoVidrio.capas.take(k + 1).fold(0.0, (a, c) => a + c.$2 * c.$2));
      expect(suma - antes, lessThanOrEqualTo(1.0));
      if (k == 0) expect(suma, lessThan(0.1), reason: 'la raya del pie');
      antes = suma;
    }
    expect(antes, closeTo(8, 0.01), reason: 'tras la hora');
    expect(
        find.descendant(
            of: find.byType(FondoVidrio), matching: find.byType(ClipRect)),
        findsNWidgets(capas.length),
        reason: 'sin recorte el desenfoque se come la pantalla');
    // Lo de abajo pasa por debajo de la barra, y el título sigue entero.
    expect(
        find.byWidgetPredicate((w) =>
            w is Text &&
            (w.data ?? '').startsWith('fila') &&
            tester.getRect(find.byWidget(w)).overlaps(barra)),
        findsWidgets);
    final titulo = tester.renderObject<RenderParagraph>(find.text('Título'));
    expect(titulo.text.style!.color!.a, 1);
  });

  testWidgets('con más contraste es opaca y sin desenfoque', (tester) async {
    await tester.pumpWidget(pantalla(contraste: true));
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();

    expect(vidrio(tester).color, Colors.white);
    expect(vidrio(tester).gradient, isNull);
    expect(desenfoca(tester), isFalse);
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

/// Los desenfoques de la barra, en el orden de [FondoVidrio.capas].
List<ui.ImageFilter> filtros(WidgetTester tester) => [
      for (final e in find
          .descendant(
              of: find.byType(FondoVidrio),
              matching: find.byType(BackdropFilter))
          .evaluate())
        (e.widget as BackdropFilter).filter!,
    ];
