import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_pasajero/core/widgets/fondo_malla.dart';

/// Las pantallas de arranque nativas (el storyboard de iOS y el
/// `launch_background.xml` de Android) no pueden pintar la malla: la llevan
/// como imagen. Esa imagen sale de este mismo pintor, así que si la malla
/// cambia y nadie regenera los PNG, el relevo nativa → Flutter salta de
/// color y esta prueba lo dice. Para regenerarlos:
/// `flutter test --update-goldens test/fondo_malla_nativo_test.dart`.
void main() {
  // Una pantalla de 390×844 a 1x: se estira a cualquier teléfono sin que se
  // note, porque la malla no tiene bordes que pixelar. A 2x pesaba 834 KB
  // por plataforma para verse igual.
  const tamano = Size(390, 844);

  Future<void> pintar(WidgetTester tester) async {
    tester.view.physicalSize = tamano;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      RepaintBoundary(
        child: CustomPaint(painter: FondoMalla.pintor(), size: tamano),
      ),
    );
  }

  testWidgets('la de iOS es la misma malla', (tester) async {
    await pintar(tester);
    await expectLater(
      find.byType(RepaintBoundary).first,
      matchesGoldenFile(
          '../ios/Runner/Assets.xcassets/FondoMalla.imageset/fondo_malla.png'),
    );
  });

  testWidgets('la de Android es la misma malla', (tester) async {
    await pintar(tester);
    await expectLater(
      find.byType(RepaintBoundary).first,
      matchesGoldenFile(
          '../android/app/src/main/res/drawable-nodpi/fondo_malla.png'),
    );
  });
}
