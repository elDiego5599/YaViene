// La pantalla de entrada del panel.
//
// Era una tarjeta angosta con el formulario solo, y el dueño la vio barata.
// Ahora es una tarjeta partida: a la izquierda, sobre tinta, «¿Olvidaste tu
// contraseña?» con la forma de pedirle ayuda al equipo —el panel no
// restablece contraseñas solo—; a la derecha, el logo y el formulario.
//
// Estas pruebas fijan lo que el dueño pidió y lo que no puede romperse:
// que el camino al equipo existe y abre su WhatsApp, que si no abre el
// número queda a la vista, que ningún texto lleva emojis, y que de la
// ventana más ancha a la más angosta, y con la letra del sistema al doble,
// nada desborda. Miden con la tipografía de la app (ver
// escalado_texto_test.dart).
import 'dart:convert';

import 'package:flutter/material.dart';
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

void main() {
  setUpAll(_cargarFuentes);

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

  for (final tamano in const [
    Size(1600, 900),
    Size(1366, 768),
    Size(1200, 800),
    Size(900, 700),
    Size(640, 800),
  ]) {
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
