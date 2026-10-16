// Los dos terminales en la tarjeta «Ruta activa» de Más.
//
// Las dos puntas se repartían el ancho mitad y mitad aunque cupieran
// enteras: en el iPhone 17, B18 salía «Ciudad Mallor… — La Playa» con
// sitio de sobra después de «La Playa». Ahora cada una mide lo suyo; solo
// cuando no caben las dos se corta la larga, y la corta queda entera.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import 'package:ya_viene_pasajero/features/mas/presentation/mas_screen.dart';

const _a = 'Ciudad Mallorquín';
const _b = 'La Playa';

double _ancho(String texto) {
  final pintor = TextPainter(
    text: TextSpan(text: texto, style: AppTextStyles.pie),
    textDirection: TextDirection.ltr,
  )..layout();
  final ancho = pintor.width;
  pintor.dispose();
  return ancho;
}

Future<void> _montar(WidgetTester tester, double ancho) => tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: ancho,
            child: const TerminalsLine(a: _a, b: _b),
          ),
        ),
      ),
    );

bool _cortado(WidgetTester tester, String texto) =>
    tester.renderObject<RenderParagraph>(find.text(texto)).didExceedMaxLines;

void main() {
  testWidgets('si caben las dos, ninguna se corta', (tester) async {
    // Las dos puntas, la línea del medio (30) y sus dos márgenes, y un poco.
    await _montar(tester, _ancho(_a) + _ancho(_b) + 60);
    expect(_cortado(tester, _a), isFalse);
    expect(_cortado(tester, _b), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('si no caben, la corta queda entera y se corta la larga',
      (tester) async {
    await _montar(tester, _ancho(_b) * 2 + 60);
    expect(_cortado(tester, _a), isTrue);
    expect(_cortado(tester, _b), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('si las dos son largas, se reparten el ancho', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: SizedBox(
            width: 200,
            child: TerminalsLine(a: _a, b: '$_a Norte'),
          ),
        ),
      ),
    );
    expect(_cortado(tester, _a), isTrue);
    expect(_cortado(tester, '$_a Norte'), isTrue);
    expect(tester.takeException(), isNull);
  });
}
