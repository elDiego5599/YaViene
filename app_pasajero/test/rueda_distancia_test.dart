// La distancia del aviso se elige con una rueda como la de la alarma del
// iPhone, de 500 m a 3 km (dueño, 2026-10-06). La primera vez que se activa
// un aviso sale en una ventana con «Guardar» y «Solo esta vez»; después,
// «Cambiar» la abre con «Guardar» y «Cancelar».
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import 'package:ya_viene_pasajero/core/widgets/dialogo.dart';
import 'package:ya_viene_pasajero/features/map/presentation/widgets/rueda_distancia.dart';

void main() {
  Future<Future<({int metros, bool guardar})?> Function()> preparar(
    WidgetTester tester, {
    int inicial = 1000,
    bool primeraVez = true,
    double escala = 1,
    Size tamano = const Size(375, 667),
  }) async {
    // Un iPhone SE, el teléfono más bajo que se sigue viendo en la calle.
    tester.view.physicalSize = tamano;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    late BuildContext ctx;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(escala)),
          child: child!,
        ),
        home: Builder(builder: (c) {
          ctx = c;
          return const Scaffold();
        }),
      ),
    );
    return () =>
        elegirDistanciaAviso(ctx, inicial: inicial, primeraVez: primeraVez);
  }

  /// Gira la rueda hasta [metros], como lo haría el dedo al soltarla ahí.
  Future<void> girarA(WidgetTester tester, int metros) async {
    final picker = tester.widget<CupertinoPicker>(find.byType(CupertinoPicker));
    picker.scrollController!.jumpToItem((metros - 500) ~/ 100);
    await tester.pumpAndSettle();
  }

  testWidgets('la primera vez pregunta en una ventana propia, en 1 km',
      (tester) async {
    final abrir = await preparar(tester);
    abrir();
    await tester.pumpAndSettle();

    expect(find.byType(Dialogo), findsOneWidget);
    expect(find.text('¿A qué distancia te avisamos?'), findsOneWidget);
    expect(find.text('Guardar'), findsOneWidget);
    expect(find.text('Solo esta vez'), findsOneWidget);
    // Los dos botones a la vista sin desplazar la ventana.
    expect(tester.getRect(find.text('Solo esta vez')).bottom, lessThan(667));
    final picker = tester.widget<CupertinoPicker>(find.byType(CupertinoPicker));
    expect(picker.scrollController!.selectedItem, 5,
        reason: 'arranca en el kilómetro de siempre');

    // De 500 m a 3 km, de 100 en 100: en los extremos no hay más.
    await girarA(tester, 500);
    expect(find.text('500 m'), findsOneWidget);
    expect(find.text('400 m'), findsNothing);
    await girarA(tester, 3000);
    expect(find.text('3,0 km'), findsOneWidget);
    expect(find.text('2,9 km'), findsOneWidget);
    expect(find.text('3,1 km'), findsNothing);
  });

  testWidgets('las distancias se escriben como en la hoja', (tester) async {
    final abrir = await preparar(tester);
    abrir();
    await tester.pumpAndSettle();

    expect(find.text('900 m'), findsOneWidget);
    expect(find.text('1,0 km'), findsOneWidget);
    expect(find.text('1,1 km'), findsOneWidget);
  });

  testWidgets('«Guardar» devuelve la distancia y pide guardarla',
      (tester) async {
    final abrir = await preparar(tester);
    final eleccion = abrir();
    await tester.pumpAndSettle();
    await girarA(tester, 1800);

    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(await eleccion, (metros: 1800, guardar: true));
    expect(find.byType(Dialogo), findsNothing);
  });

  testWidgets('«Solo esta vez» devuelve la distancia sin guardarla',
      (tester) async {
    final abrir = await preparar(tester);
    final eleccion = abrir();
    await tester.pumpAndSettle();
    await girarA(tester, 600);

    await tester.tap(find.text('Solo esta vez'));
    await tester.pumpAndSettle();

    expect(await eleccion, (metros: 600, guardar: false));
  });

  testWidgets('girar la rueda con el dedo cambia la distancia', (tester) async {
    final abrir = await preparar(tester);
    final eleccion = abrir();
    await tester.pumpAndSettle();

    // Hacia arriba sube la distancia.
    await tester.drag(find.byType(CupertinoPicker), const Offset(0, -120));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    final r = await eleccion;
    expect(r!.metros, greaterThan(1000));
    expect(r.metros % 100, 0);
  });

  testWidgets('tocar fuera cierra sin elegir', (tester) async {
    final abrir = await preparar(tester);
    final eleccion = abrir();
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();

    expect(await eleccion, isNull);
  });

  testWidgets('«Cambiar» abre en la distancia de ahora, con «Cancelar»',
      (tester) async {
    final abrir = await preparar(tester, inicial: 2200, primeraVez: false);
    final eleccion = abrir();
    await tester.pumpAndSettle();

    expect(find.text('Distancia del aviso'), findsOneWidget);
    expect(find.text('Solo esta vez'), findsNothing);
    final picker = tester.widget<CupertinoPicker>(find.byType(CupertinoPicker));
    expect(picker.scrollController!.selectedItem, 17);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(await eleccion, isNull);
  });

  testWidgets('una distancia que la rueda no ofrece arranca en la más cercana',
      (tester) async {
    final abrir = await preparar(tester, inicial: 4000, primeraVez: false);
    abrir();
    await tester.pumpAndSettle();

    final picker = tester.widget<CupertinoPicker>(find.byType(CupertinoPicker));
    expect(picker.scrollController!.selectedItem, 25);
  });

  testWidgets('el lector la anuncia y la sube o baja de 100 en 100',
      (tester) async {
    final semantica = tester.ensureSemantics();
    final abrir = await preparar(tester);
    final eleccion = abrir();
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Distancia del aviso'), findsOneWidget);
    // Dicha en palabras, como la distancia de la hoja: «km» leído en voz
    // alta son dos letras sueltas.
    final rueda = find.semantics.byValue('1,0 kilómetros');
    expect(rueda, findsOne);
    final nodo = rueda.evaluate().single;
    expect(nodo.getSemanticsData().increasedValue, '1,1 kilómetros');
    expect(nodo.getSemanticsData().decreasedValue, '900 metros');

    tester.semantics.increase(rueda);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect((await eleccion)!.metros, 1100);
    semantica.dispose();
  });

  testWidgets('con el texto al doble cabe en un teléfono pequeño',
      (tester) async {
    final abrir =
        await preparar(tester, escala: 2, tamano: const Size(320, 568));
    abrir();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // La fila crece con el texto: la cifra elegida no se recorta.
    final cifra = tester.getSize(find.text('1,0 km'));
    final picker = tester.widget<CupertinoPicker>(find.byType(CupertinoPicker));
    expect(picker.itemExtent, greaterThanOrEqualTo(cifra.height));
    // Y se puede llegar a los botones desplazando la ventana.
    await tester.ensureVisible(find.text('Solo esta vez'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('la cifra elegida contrasta con su franja (WCAG AA)',
      (tester) async {
    final abrir = await preparar(tester);
    abrir();
    await tester.pumpAndSettle();

    final texto = tester.widget<Text>(find.text('1,0 km'));
    final franja = franjaRuedaDistancia;
    // La franja es translúcida sobre el blanco de la ventana.
    final fondo = Color.alphaBlend(franja, Colors.white);
    final tinta = texto.style?.color ??
        DefaultTextStyle.of(
          tester.element(find.text('1,0 km')),
        ).style.color!;
    expect(contraste(tinta, fondo), greaterThanOrEqualTo(4.5));
  });
}

double contraste(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  final (claro, oscuro) = la > lb ? (la, lb) : (lb, la);
  return (claro + 0.05) / (oscuro + 0.05);
}
