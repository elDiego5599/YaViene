// La pantalla de entrada del panel.
//
// Era una tarjeta angosta con el formulario solo, y el dueño la vio barata.
// Ahora es una tarjeta partida: a la izquierda, sobre el degradado del 404
// de la web, «¿Olvidaste tu contraseña?» con la forma de pedirle ayuda al
// equipo —el panel no restablece contraseñas solo—; a la derecha, el logo y
// el formulario. El filo entre las dos mitades es el arco de la imagen de
// referencia del dueño.
//
// Estas pruebas fijan lo que el dueño pidió y lo que no puede romperse:
// que el camino al equipo existe y abre su WhatsApp, que si no abre el
// número queda a la vista, que ningún texto lleva emojis, y que de la
// ventana más ancha a la más angosta, y con la letra del sistema al doble,
// nada desborda. Miden con la tipografía de la app (ver
// escalado_texto_test.dart).
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_control/core/theme/app_theme.dart';
import 'package:ya_viene_control/features/auth/presentation/screens/login_screen.dart';
import 'package:ya_viene_core/core/providers/app_providers.dart'
    show BackendUrl, backendUrlProvider;

Future<void> _cargarFuentes() async {
  final manifiesto =
      json.decode(await rootBundle.loadString('FontManifest.json'))
          as List<dynamic>;
  for (final entrada in manifiesto.cast<Map<String, dynamic>>()) {
    final cargador = FontLoader(entrada['family'] as String);
    final fuentes = (entrada['fonts'] as List).cast<Map<String, dynamic>>();
    for (final fuente in fuentes) {
      cargador.addFont(rootBundle.load(fuente['asset'] as String));
    }
    await cargador.load();
  }
}

/// Monta el login con un abridor de enlaces falso que anota lo que le
/// piden y contesta [abre].
Future<List<Uri>> _montar(
  WidgetTester tester, {
  Size tamano = const Size(1366, 768),
  double escala = 1.0,
  bool abre = true,
}) async {
  await tester.binding.setSurfaceSize(tamano);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  tester.platformDispatcher.textScaleFactorTestValue = escala;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

  final abiertos = <Uri>[];
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        backendUrlProvider.overrideWith(
          () => BackendUrl.fija('http://localhost:3000'),
        ),
        abrirEnlaceProvider.overrideWithValue((uri) async {
          abiertos.add(uri);
          return abre;
        }),
      ],
      child: MaterialApp(theme: AppTheme.light, home: const LoginScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return abiertos;
}

/// Emojis y pictogramas: los bloques suplementarios de símbolos, los
/// «misceláneos» y dingbats, y el selector que vuelve emoji a un carácter.
bool _esEmoji(int c) =>
    (c >= 0x1F000 && c <= 0x1FAFF) ||
    (c >= 0x2600 && c <= 0x27BF) ||
    c == 0xFE0F;

/// Luminancia relativa y contraste WCAG 2.
double _contraste(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// [arriba] con su transparencia, puesto sobre [fondo] opaco.
Color _sobre(Color arriba, Color fondo) =>
    Color.alphaBlend(arriba, fondo.withValues(alpha: 1));

/// El lienzo del degradado y si está partido o apilado.
({Rect lienzo, bool partido}) _fondo(WidgetTester tester) {
  final lienzo = tester.getRect(find.byKey(const ValueKey('fondo-equipo')));
  final boton = tester.getRect(find.text('INGRESAR'));
  // Partida, el lienzo cubre la tarjeta entera, formulario incluido;
  // apilada, solo la franja de abajo.
  return (lienzo: lienzo, partido: lienzo.contains(boton.center));
}

/// Lo que va en el panel: cada hijo de su columna (la cápsula de «SOPORTE»,
/// el título, el cuerpo, el botón, el número), en coordenadas globales.
List<Rect> _piezasDelPanel(WidgetTester tester) {
  final columna = tester.renderObject<RenderFlex>(
    find.byKey(const ValueKey('panel-equipo')),
  );
  final piezas = <Rect>[];
  columna.visitChildren((hijo) {
    final caja = hijo as RenderBox;
    if (caja.size.isEmpty) return; // los SizedBox de aire
    piezas.add(caja.localToGlobal(Offset.zero) & caja.size);
  });
  return piezas;
}

const _tamanos = [
  Size(1600, 900),
  Size(1366, 768),
  Size(1200, 800),
  Size(900, 700),
  Size(640, 800),
];

void main() {
  setUpAll(_cargarFuentes);

  test('el filo es el arco de la referencia: arriba en el 52 %, abajo en el '
      '29 %, y casi vertical en el primer tercio', () {
    const tarjeta = Size(1000, 600);
    double x(double t) => FondoEquipo.filo(tarjeta, t * 600) / 1000;
    // Medidas sobre la imagen que mandó el dueño (fracción del alto →
    // fracción del ancho), con ±1,5 % de holgura de la medición a ojo.
    const referencia = [
      (0.0, 0.52),
      (0.25, 0.506),
      (0.41, 0.483),
      (0.61, 0.453),
      (0.79, 0.40),
      (1.0, 0.294),
    ];
    for (final (t, esperado) in referencia) {
      expect(x(t), closeTo(esperado, 0.015), reason: 'a t = $t');
    }
    // Siempre hacia la izquierda al bajar.
    for (var i = 1; i <= 100; i++) {
      expect(x(i / 100), lessThanOrEqualTo(x((i - 1) / 100)));
    }
  });

  test('el degradado es el del 404: #17325F a #00A859', () {
    expect(FondoEquipo.azul, const Color(0xFF17325F));
    expect(FondoEquipo.verde, const Color(0xFF00A859));
    const lienzo = Size(1000, 600);
    expect(
      FondoEquipo.colorEn(Offset.zero, lienzo, partido: true),
      FondoEquipo.azul,
    );
    expect(
      FondoEquipo.colorEn(const Offset(520, 720), lienzo, partido: true),
      FondoEquipo.verde,
    );
  });

  for (final tamano in _tamanos) {
    for (final escala in const [1.0, 1.3, 2.0]) {
      final nombre =
          '${tamano.width.toInt()}×${tamano.height.toInt()} y '
          '$escala×';

      testWidgets('a $nombre el texto del panel queda del lado del color, '
          'con aire antes del filo', (tester) async {
        await _montar(tester, tamano: tamano, escala: escala);
        final (:lienzo, :partido) = _fondo(tester);

        for (final pieza in _piezasDelPanel(tester)) {
          expect(pieza.left, greaterThanOrEqualTo(lienzo.left + 16));
          if (!partido) {
            expect(pieza.right, lessThanOrEqualTo(lienzo.right - 16));
            continue;
          }
          // El filo se mete al bajar: el borde de abajo de cada pieza es
          // donde menos lugar le queda.
          final filo =
              lienzo.left +
              FondoEquipo.filo(lienzo.size, pieza.bottom - lienzo.top);
          expect(
            pieza.right + 16,
            lessThanOrEqualTo(filo),
            reason:
                'una pieza del panel llega a ${pieza.right} y el filo '
                'está en $filo',
          );
        }
      });

      testWidgets('a $nombre cada texto del panel se lee sobre el degradado', (
        tester,
      ) async {
        await _montar(tester, tamano: tamano, escala: escala);
        final (:lienzo, :partido) = _fondo(tester);

        final textos = find.descendant(
          of: find.byKey(const ValueKey('panel-equipo')),
          matching: find.byType(RichText),
        );
        expect(textos, findsAtLeastNWidgets(5));
        for (final elemento in textos.evaluate()) {
          final texto = elemento.widget as RichText;
          final estilo = texto.text.style!;
          final caja = tester.getRect(find.byWidget(texto));
          // Un degradado lineal tiene sus extremos en las esquinas: la peor
          // está en una de las cuatro.
          final peor =
              [caja.topLeft, caja.topRight, caja.bottomLeft, caja.bottomRight]
                  .map(
                    (p) => FondoEquipo.colorEn(
                      p - lienzo.topLeft,
                      lienzo.size,
                      partido: partido,
                    ),
                  )
                  .map(
                    (fondo) => _contraste(_sobre(estilo.color!, fondo), fondo),
                  )
                  .reduce(math.min);
          // WCAG AA: 3:1 para texto grande (24 pt, o 18,66 en negrita).
          final tamanoLetra = estilo.fontSize! * escala;
          final grande =
              tamanoLetra >= 24 ||
              (tamanoLetra >= 18.66 &&
                  (estilo.fontWeight?.value ?? 400) >= 700);
          expect(
            peor,
            greaterThanOrEqualTo(grande ? 3.0 : 4.5),
            reason:
                '«${texto.text.toPlainText()}» queda en '
                '${peor.toStringAsFixed(2)}:1',
          );
        }
      });
    }
  }

  testWidgets('a la izquierda está «¿Olvidaste tu contraseña?» y a la '
      'derecha el formulario', (tester) async {
    await _montar(tester);

    final panel = tester.getCenter(find.text('¿Olvidaste tu contraseña?'));
    final boton = tester.getCenter(find.text('INGRESAR'));
    expect(panel.dx, lessThan(boton.dx));
    expect(find.text('Iniciar sesión'), findsOneWidget);
    expect(find.text('Escribir al equipo'), findsOneWidget);
  });

  testWidgets('«Escribir al equipo» abre el WhatsApp del equipo con el '
      'mensaje ya escrito', (tester) async {
    final abiertos = await _montar(tester);

    await tester.tap(find.text('Escribir al equipo'));
    await tester.pump();

    expect(abiertos, hasLength(1));
    final uri = abiertos.single;
    // El mismo número que la web publica en empresas.html.
    expect(uri.host, 'wa.me');
    expect(uri.path, '/573004438626');
    expect(uri.queryParameters['text'], contains('contraseña'));
  });

  testWidgets('si WhatsApp no abre, el número queda escrito en un aviso', (
    tester,
  ) async {
    await _montar(tester, abre: false);

    await tester.tap(find.text('Escribir al equipo'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('No se pudo abrir WhatsApp'), findsOneWidget);
    expect(find.textContaining('+57 300 443 8626'), findsWidgets);
  });

  testWidgets('ningún texto de la pantalla lleva emojis', (tester) async {
    await _montar(tester);

    for (final texto in tester.widgetList<RichText>(find.byType(RichText))) {
      final plano = texto.text.toPlainText();
      expect(
        plano.runes.where(_esEmoji),
        isEmpty,
        reason: '«$plano» lleva un emoji',
      );
    }
  });

  testWidgets('la contraseña se muestra y se oculta con su botón', (
    tester,
  ) async {
    await _montar(tester);

    expect(find.byTooltip('Mostrar contraseña'), findsOneWidget);
    await tester.tap(find.byTooltip('Mostrar contraseña'));
    await tester.pump();
    expect(find.byTooltip('Ocultar contraseña'), findsOneWidget);
  });

  testWidgets('en una ventana angosta el panel del equipo baja bajo el '
      'formulario', (tester) async {
    await _montar(tester, tamano: const Size(640, 900));

    final panel = tester.getRect(find.text('¿Olvidaste tu contraseña?'));
    final boton = tester.getRect(find.text('INGRESAR'));
    expect(panel.top, greaterThan(boton.bottom));
    expect(tester.takeException(), isNull);
  });

  for (final tamano in _tamanos) {
    for (final escala in const [1.0, 2.0]) {
      testWidgets('a ${tamano.width.toInt()}×${tamano.height.toInt()} y '
          '$escala× nada desborda', (tester) async {
        await _montar(tester, tamano: tamano, escala: escala);

        expect(tester.takeException(), isNull);
        expect(find.text('INGRESAR'), findsOneWidget);
        expect(find.text('¿Olvidaste tu contraseña?'), findsOneWidget);
      });
    }
  }
}
