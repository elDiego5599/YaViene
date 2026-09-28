import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import 'package:ya_viene_pasajero/core/widgets/cifra_viva.dart';

/// La distancia de la hoja del bus cambia con cada posición que llega. Un
/// salto seco de «850» a «849» no se lee como algo que avanza; en iOS los
/// números vivos giran solo en las cifras que cambian. `CifraViva` hace eso
/// y, en reposo, es un `Text` como el de antes: mismas pruebas, misma voz.
void main() {
  Widget montar(String texto, {bool reducido = false, double? valor}) {
    return MediaQuery(
      data: MediaQueryData(disableAnimations: reducido),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: CifraViva(
            texto,
            valor: valor,
            style: AppTextStyles.dato,
          ),
        ),
      ),
    );
  }

  Iterable<Text> textos(WidgetTester tester) =>
      tester.widgetList<Text>(find.byType(Text));

  testWidgets('en reposo es un solo Text, con cifras de ancho fijo',
      (tester) async {
    await tester.pumpWidget(montar('850'));
    expect(find.text('850'), findsOneWidget);
    expect(textos(tester), hasLength(1));
    // Cifras tabulares: «111» y «888» miden lo mismo y el número no
    // tiembla de ancho cuando cambia cada segundo.
    final estilo = tester.widget<Text>(find.text('850')).style!;
    expect(estilo.fontFeatures, contains(const FontFeature.tabularFigures()));
  });

  testWidgets('al cambiar, giran solo las cifras que cambian', (tester) async {
    await tester.pumpWidget(montar('850', valor: 850));
    await tester.pumpWidget(montar('849', valor: 849));
    await tester.pump(const Duration(milliseconds: 120));

    // A medio giro: el 8 se queda quieto (un solo Text), el 5 y el 0 se
    // van mientras entran el 4 y el 9.
    expect(find.text('850'), findsNothing);
    expect(find.text('8'), findsOneWidget);
    for (final cifra in ['5', '0', '4', '9']) {
      expect(find.text(cifra), findsOneWidget, reason: cifra);
    }

    await tester.pumpAndSettle();
    expect(find.text('849'), findsOneWidget);
    expect(textos(tester), hasLength(1));
  });

  testWidgets('baja la distancia: lo nuevo entra desde arriba', (tester) async {
    await tester.pumpWidget(montar('850', valor: 850));
    await tester.pumpWidget(montar('849', valor: 849));
    await tester.pump(const Duration(milliseconds: 60));
    final nuevo = tester.getCenter(find.text('9'));
    final viejo = tester.getCenter(find.text('0'));
    expect(nuevo.dy, lessThan(viejo.dy));
  });

  testWidgets('sube la distancia: lo nuevo entra desde abajo', (tester) async {
    await tester.pumpWidget(montar('849', valor: 849));
    await tester.pumpWidget(montar('850', valor: 850));
    await tester.pump(const Duration(milliseconds: 60));
    final nuevo = tester.getCenter(find.text('0'));
    final viejo = tester.getCenter(find.text('9'));
    expect(nuevo.dy, greaterThan(viejo.dy));
  });

  testWidgets('de palabra a número no gira: cambia en seco', (tester) async {
    await tester.pumpWidget(montar('Calculando'));
    await tester.pumpWidget(montar('850', valor: 850));
    await tester.pump();
    expect(find.text('850'), findsOneWidget);
    expect(textos(tester), hasLength(1));
  });

  testWidgets('con movimiento reducido cambia en seco', (tester) async {
    await tester.pumpWidget(montar('850', reducido: true, valor: 850));
    await tester.pumpWidget(montar('849', reducido: true, valor: 849));
    await tester.pump();
    expect(find.text('849'), findsOneWidget);
    expect(textos(tester), hasLength(1));
  });

  testWidgets('un giro cortado por otro cambio termina en el último',
      (tester) async {
    await tester.pumpWidget(montar('850', valor: 850));
    await tester.pumpWidget(montar('849', valor: 849));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpWidget(montar('848', valor: 848));
    await tester.pumpAndSettle();
    expect(find.text('848'), findsOneWidget);
    expect(textos(tester), hasLength(1));
  });

  testWidgets('en reposo no pinta cuadros', (tester) async {
    await tester.pumpWidget(montar('850', valor: 850));
    await tester.pumpWidget(montar('849', valor: 849));
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
  });
}
