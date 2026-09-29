// La guía de contraste a tres píxeles por punto mide lo mismo que la de
// Flutter donde el suavizado no estorba, y no deja pasar nada que la de
// Flutter tumbaría por contraste de verdad.
//
// Aquí se pinta con la letra de pruebas del motor, que dibuja cada glifo
// como un bloque macizo: sin bordes suavizados que decidan la medida, las
// dos guías tienen que dar el mismo veredicto. El caso que motivó la guía
// (letra real de 9,5 a 15 puntos que en Linux se mide como su borde) lo
// cubren las pruebas de accesibilidad de las dos apps, que cargan la
// tipografía de verdad.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_pruebas/contraste.dart';

/// Blanco puro: el fondo de las tarjetas.
const _blanco = Color(0xFFFFFFFF);

/// `AppColors.textSecondary`: 5,4:1 sobre blanco. Pasa para cualquier texto.
const _grisBueno = Color(0xFF5E6B82);

/// El gris que el panel usaba antes de T6.1: 2,56:1 sobre blanco. No pasa
/// ni como texto grande.
const _grisMalo = Color(0xFF94A3B8);

/// 3,45:1 sobre blanco: pasa como texto grande (3:1) y no como normal (4,5:1).
const _grisGrande = Color(0xFF8A8A8A);

/// Un gris claro de relleno, 1,6:1 sobre blanco: si se midiera como color
/// del texto, reprobaría.
const _bloque = Color(0xFFCCCCCC);

Future<void> _pintar(
  WidgetTester tester,
  Color color, {
  double tamano = 14,
  FontWeight peso = FontWeight.normal,
  double velo = 0,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        backgroundColor: _blanco,
        body: Center(
          child: Stack(
            children: [
              Text(
                'Ya viene',
                style: TextStyle(
                  color: color,
                  fontSize: tamano,
                  fontWeight: peso,
                ),
              ),
              // Un velo blanco encima, como un degradado que tapa el final
              // de una lista: el texto sigue en el árbol pero se lee menos.
              if (velo > 0)
                Positioned.fill(
                  child: IgnorePointer(
                    child: ColoredBox(color: _blanco.withValues(alpha: velo)),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Pasa o no pasa, según la guía.
Future<bool> _pasa(WidgetTester tester, AccessibilityGuideline guia) async {
  final evaluacion = await guia.evaluate(tester);
  return evaluacion.passed;
}

void main() {
  testWidgets('un gris con contraste de sobra pasa', (tester) async {
    final semantica = tester.ensureSemantics();
    await _pintar(tester, _grisBueno);
    await expectLater(tester, meetsGuideline(guiaContraste));
    semantica.dispose();
  });

  testWidgets('un gris sin contraste sigue fallando: el umbral es el mismo',
      (tester) async {
    final semantica = tester.ensureSemantics();
    await _pintar(tester, _grisMalo);
    // Una guía que aprobara todo caería aquí. Y no basta con que repruebe:
    // tiene que haber medido el gris de verdad sobre el blanco, 2,56:1.
    final evaluacion = await guiaContraste.evaluate(tester);
    expect(evaluacion.passed, isFalse);
    expect(evaluacion.reason, contains('but found 2.56'));
    semantica.dispose();
  });

  testWidgets('el texto grande pide 3:1 y el normal 4,5:1', (tester) async {
    final semantica = tester.ensureSemantics();
    await _pintar(tester, _grisGrande, tamano: 20);
    await expectLater(tester, meetsGuideline(guiaContraste));
    await _pintar(tester, _grisGrande, tamano: 14, peso: FontWeight.bold);
    await expectLater(tester, meetsGuideline(guiaContraste));
    await _pintar(tester, _grisGrande, tamano: 14);
    await expectLater(tester, doesNotMeetGuideline(guiaContraste));
    semantica.dispose();
  });

  testWidgets('lo que tapa el texto se ve: se mide lo pintado', (tester) async {
    final semantica = tester.ensureSemantics();
    // Sin velo, el gris bueno pasa; con un velo blanco al 60 % lo que llega
    // a la pantalla ya es un gris pálido, y eso es lo que se mide.
    await _pintar(tester, _grisBueno, velo: 0.6);
    await expectLater(tester, doesNotMeetGuideline(guiaContraste));
    semantica.dispose();
  });

  testWidgets('mide la caja del texto entera y nada fuera de ella',
      (tester) async {
    final semantica = tester.ensureSemantics();
    // Un texto bueno con un bloque gris claro arriba a la izquierda, a más
    // de cuatro puntos de su caja: no es del texto y no cuenta. Si la caja
    // se llevara mal a la foto (una esquina en puntos y la otra en
    // píxeles, o sin escalar), la muestra caería en el bloque y el gris
    // claro pasaría por el color del texto.
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          backgroundColor: _blanco,
          body: Stack(
            children: [
              Positioned(
                left: 40,
                top: 40,
                width: 340,
                height: 240,
                child: ColoredBox(color: _bloque),
              ),
              Positioned(
                left: 400,
                top: 300,
                child: Text(
                  'Ya viene',
                  style: TextStyle(color: _grisBueno, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await expectLater(tester, meetsGuideline(guiaContraste));
    semantica.dispose();
  });

  testWidgets('sin suavizado de por medio, da lo mismo que la de Flutter',
      (tester) async {
    final semantica = tester.ensureSemantics();
    final casos = <(Color, double, FontWeight, double)>[
      (_grisBueno, 14, FontWeight.normal, 0),
      (_grisMalo, 14, FontWeight.normal, 0),
      (_grisGrande, 20, FontWeight.normal, 0),
      (_grisGrande, 14, FontWeight.bold, 0),
      (_grisGrande, 14, FontWeight.normal, 0),
      (_grisBueno, 14, FontWeight.normal, 0.6),
    ];
    for (final (color, tamano, peso, velo) in casos) {
      await _pintar(tester, color, tamano: tamano, peso: peso, velo: velo);
      expect(
        await _pasa(tester, guiaContraste),
        await _pasa(tester, textContrastGuideline),
        reason: '$color a $tamano puntos, peso $peso, velo $velo',
      );
    }
    semantica.dispose();
  });

  test('fotografía a tres píxeles por punto', () {
    expect(guiaContraste, isA<GuiaContraste>());
    expect((guiaContraste as GuiaContraste).escala, 3);
    expect(guiaContraste.description, textContrastGuideline.description);
  });
}
