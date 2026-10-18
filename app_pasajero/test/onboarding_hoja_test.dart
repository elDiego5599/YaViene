import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import 'package:ya_viene_pasajero/core/widgets/fondo_malla.dart';
import 'package:ya_viene_pasajero/core/widgets/ink_hero.dart';
import 'package:ya_viene_pasajero/features/onboarding/presentation/screens/'
    'onboarding_screen.dart';

import 'golden/golden_harness.dart';
import 'helpers/contraste.dart';

/// La hoja de la bienvenida: pocas palabras y grandes.
///
/// El dueño (2026-09-27): «hay mucho texto y hace que todos se vean
/// pequeños». La hoja decía lo mismo tres veces —un subtítulo y una letra
/// chica por cada razón— y para que cupiera todo, todo iba a 12 y 15. Se
/// quedó lo necesario: el título, tres razones de una línea, el sí legal y
/// los dos botones. Estas pruebas fijan que no vuelva lo que se fue y que
/// lo que se quedó conserve su tamaño.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> abrir(WidgetTester tester) async {
    fijarPantalla(tester);
    await tester.pumpWidget(
      ProviderScope(child: marcoGoldenRuteado(const OnboardingScreen())),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
  }

  double tamano(WidgetTester tester, String texto) =>
      tester.widget<Text>(find.text(texto)).style!.fontSize!;

  testWidgets('sin subtítulo ni letra chica bajo cada razón', (tester) async {
    await abrir(tester);

    for (final ido in [
      'Así sabemos qué buses vienen hacia ti y te avisamos antes de que '
          'llegue el tuyo.',
      'Ves dónde va el tuyo, no dónde debería ir',
      'Calculado con la posición real del bus',
      'Suena cuando se acerca a tu punto de espera',
    ]) {
      expect(find.text(ido), findsNothing, reason: ido);
    }
  });

  testWidgets('el título y las razones van a su tamaño de encabezado',
      (tester) async {
    await abrir(tester);

    expect(
        tamano(tester, 'Activa tu ubicación'), AppTextStyles.display.fontSize);
    for (final razon in [
      'Buses en vivo',
      'A qué distancia viene',
      'Aviso antes de que llegue',
    ]) {
      expect(tamano(tester, razon), AppTextStyles.subtitulo.fontSize,
          reason: razon);
    }
  });

  testWidgets('el labio de la hoja proyecta su sombra hacia arriba',
      (tester) async {
    // La hoja está abajo y la noche arriba: la sombra que la separa cae
    // sobre la noche. `AppShadows.floating` es la de una tarjeta que flota
    // sobre el suelo —hacia abajo— y aquí se perdía bajo el borde de la
    // pantalla (R-14).
    await abrir(tester);

    // Blanca lisa (dueño, 2026-10-16): ya no el blanco cálido que caía a
    // arena; es la única caja con los cantos de una hoja.
    final hoja = tester.widgetList<Container>(find.byType(Container)).where(
          (c) =>
              c.decoration is BoxDecoration &&
              (c.decoration! as BoxDecoration).borderRadius ==
                  const BorderRadius.only(
                    topLeft: Radius.circular(AppRadius.sheet),
                    topRight: Radius.circular(AppRadius.sheet),
                  ),
        );
    expect(hoja, hasLength(1));
    expect((hoja.single.decoration! as BoxDecoration).gradient, isNull);
    expect((hoja.single.decoration! as BoxDecoration).color, AppColors.surface);
    final sombras = (hoja.single.decoration! as BoxDecoration).boxShadow!;
    expect(sombras, isNotEmpty);
    for (final sombra in sombras) {
      expect(sombra.offset.dy, lessThan(0));
      expect(sombra.color, AppColors.primaryDeep.withValues(alpha: 0.08));
    }
  });

  // «En la pestaña de onboarding debería estar el mismo fondo» (dueño,
  // 2026-10-16): la malla que respira del arranque, no la noche con rutas.
  testWidgets('el fondo es la malla del arranque', (tester) async {
    await abrir(tester);
    final malla = tester.widget<FondoMalla>(find.byType(FondoMalla));
    expect(malla.subida, subidaMalla);
  });

  testWidgets('el nombre y la bajada se leen sobre la malla en todo el ciclo',
      (tester) async {
    await abrir(tester);
    final pantalla = tester.view.physicalSize;
    final piezas = [
      (find.text('Ya Viene'), Colors.white, 3.0),
      (
        find.text('Tu ciudad en tiempo real.'),
        Colors.white.withValues(alpha: InkHero.alfaBajada),
        4.5,
      ),
    ];
    final cajas = [for (final (f, _, _) in piezas) tester.getRect(f)];
    for (var fase = 0.0; fase < 1; fase += 0.125) {
      late ByteData datos;
      await tester.runAsync(() async {
        final grabadora = ui.PictureRecorder();
        FondoMalla.pintor(fase: fase, subida: subidaMalla)
            .paint(Canvas(grabadora), pantalla);
        final imagen = await grabadora
            .endRecording()
            .toImage(pantalla.width.toInt(), pantalla.height.toInt());
        datos = (await imagen.toByteData(format: ui.ImageByteFormat.rawRgba))!;
      });
      for (final (i, (_, letra, minimo)) in piezas.indexed) {
        final caja = cajas[i];
        for (var y = caja.top; y <= caja.bottom; y += 4) {
          for (var x = caja.left; x <= caja.right; x += 6) {
            final j = (y.floor() * pantalla.width.toInt() + x.floor()) * 4;
            final fondo = Color.fromARGB(255, datos.getUint8(j),
                datos.getUint8(j + 1), datos.getUint8(j + 2));
            exigeContraste(contraste(Color.alphaBlend(letra, fondo), fondo),
                minimo, 'pieza $i en ($x, $y), fase $fase');
          }
        }
      }
    }
  });
}
