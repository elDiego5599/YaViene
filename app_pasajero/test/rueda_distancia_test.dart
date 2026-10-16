// La distancia del aviso se elige con una rueda como la de la alarma del
// iPhone, de 500 m a 3 km en pasos de 100 m (dueño, 2026-10-06). Aquí, la
// rueda sola; cómo la pregunta la tarjeta del bus está en
// eta_sheet_distancia_test.dart.
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import 'package:ya_viene_pasajero/features/map/presentation/widgets/rueda_distancia.dart';

void main() {
  /// Monta la rueda en [inicial] y devuelve la lista de lo que va diciendo.
  Future<List<int>> montar(
    WidgetTester tester, {
    int inicial = 1000,
    double escala = 1,
  }) async {
    final elegidas = <int>[];
    // Un iPhone 13 de pie: en la pantalla de prueba (800×600) la rueda se
    // quedaría en tres filas por baja.
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(escala)),
          child: child!,
        ),
        home: Scaffold(
          body: Center(
            child: RuedaDistancia(inicial: inicial, alCambiar: elegidas.add),
          ),
        ),
      ),
    );
    return elegidas;
  }

  CupertinoPicker rueda(WidgetTester tester) =>
      tester.widget<CupertinoPicker>(find.byType(CupertinoPicker));

  /// Gira la rueda hasta [metros], como lo haría el dedo al soltarla ahí.
  Future<void> girarA(WidgetTester tester, int metros) async {
    rueda(tester).scrollController!.jumpToItem((metros - 500) ~/ 100);
    await tester.pumpAndSettle();
  }

  testWidgets('va de 500 m a 3 km, de 100 en 100', (tester) async {
    final elegidas = await montar(tester);
    expect(rueda(tester).scrollController!.selectedItem, 5,
        reason: 'arranca en la que se le pide');

    await girarA(tester, 500);
    expect(find.text('500 m'), findsOneWidget);
    expect(find.text('400 m'), findsNothing);
    await girarA(tester, 3000);
    expect(find.text('3,0 km'), findsOneWidget);
    expect(find.text('2,9 km'), findsOneWidget);
    expect(find.text('3,1 km'), findsNothing);
    expect(elegidas.last, 3000);
  });

  testWidgets('las distancias se escriben como en la hoja', (tester) async {
    await montar(tester);
    expect(find.text('900 m'), findsOneWidget);
    expect(find.text('1,0 km'), findsOneWidget);
    expect(find.text('1,1 km'), findsOneWidget);
  });

  /// Las cifras que la rueda pinta, de arriba abajo.
  List<String> aLaVista(WidgetTester tester) => tester
      .widgetList<Text>(find.descendant(
          of: find.byType(CupertinoPicker), matching: find.byType(Text)))
      .map((t) => t.data!)
      .toList();

  // Dos arriba y dos abajo, y ni media más asomando en los bordes (dueño,
  // 2026-10-06): con la altura de cinco filas el picker apretaba siete.
  testWidgets('se ven dos arriba y dos abajo de la elegida', (tester) async {
    await montar(tester);
    expect(aLaVista(tester), ['800 m', '900 m', '1,0 km', '1,1 km', '1,2 km']);
  });

  testWidgets('girarla con el dedo dice la distancia nueva', (tester) async {
    final elegidas = await montar(tester);
    // Hacia arriba sube la distancia.
    await tester.drag(find.byType(CupertinoPicker), const Offset(0, -120));
    await tester.pumpAndSettle();
    expect(elegidas.last, greaterThan(1000));
    expect(elegidas.last % 100, 0);
  });

  testWidgets('una distancia que la rueda no ofrece arranca en la más cercana',
      (tester) async {
    await montar(tester, inicial: 4000);
    expect(rueda(tester).scrollController!.selectedItem, 25);
  });

  testWidgets('el lector la anuncia y la sube o baja de 100 en 100',
      (tester) async {
    final semantica = tester.ensureSemantics();
    final elegidas = await montar(tester);

    expect(find.bySemanticsLabel('Distancia del aviso'), findsOneWidget);
    // Dicha en palabras, como la distancia de la hoja: «km» leído en voz
    // alta son dos letras sueltas.
    final nodo = find.semantics.byValue('1,0 kilómetros');
    expect(nodo, findsOne);
    final datos = nodo.evaluate().single.getSemanticsData();
    expect(datos.increasedValue, '1,1 kilómetros');
    expect(datos.decreasedValue, '900 metros');

    tester.semantics.increase(nodo);
    await tester.pumpAndSettle();
    expect(elegidas.last, 1100);
    semantica.dispose();
  });

  testWidgets('con el texto grande la fila crece y se ven tres',
      (tester) async {
    await montar(tester, escala: 2);
    expect(tester.takeException(), isNull);
    final fila = rueda(tester).itemExtent;
    expect(
        fila, greaterThanOrEqualTo(tester.getSize(find.text('1,0 km')).height));
    expect(aLaVista(tester), ['900 m', '1,0 km', '1,1 km']);
  });

  testWidgets('la cifra elegida contrasta con su franja (WCAG AA)',
      (tester) async {
    await montar(tester);
    final texto = tester.widget<Text>(find.text('1,0 km'));
    // La franja es translúcida sobre el blanco de la tarjeta del bus.
    final fondo = Color.alphaBlend(franjaRuedaDistancia, AppColors.surface);
    expect(contraste(texto.style!.color!, fondo), greaterThanOrEqualTo(4.5));
  });

  // Cada paso de la rueda se siente en el dedo, como en la alarma del
  // iPhone (referentes, 2026-10-16). En iOS ya lo da el propio picker; en
  // Android no daba nada. Uno por paso, nunca dos.
  testWidgets('un toque háptico por paso', (tester) async {
    final toques = <Object?>[];
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (llamada) async {
      if (llamada.method == 'HapticFeedback.vibrate') {
        toques.add(llamada.arguments);
      }
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    await montar(tester);
    await girarA(tester, 1200);
    await girarA(tester, 1300);
    expect(toques, List.filled(2, 'HapticFeedbackType.selectionClick'));
  },
      variant: const TargetPlatformVariant(
          {TargetPlatform.android, TargetPlatform.iOS}));
}

double contraste(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  final (claro, oscuro) = la > lb ? (la, lb) : (lb, la);
  return (claro + 0.05) / (oscuro + 0.05);
}
