// La cabecera del panel dice cuándo el panel habla con el respaldo (T2.3).
//
// Con D1 = espejo de la demo, el respaldo sirve una flota simulada a
// propósito: el operador tiene que saber que lo que ve en el mapa no es la
// flota del túnel. Lo dice una línea discreta junto al estado de la conexión.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_control/core/theme/app_theme.dart';
import 'package:ya_viene_control/features/fleet/presentation/providers/fleet_providers.dart';
import 'package:ya_viene_control/features/fleet/presentation/screens/dashboard_screen.dart';
import 'package:ya_viene_core/core/providers/app_providers.dart'
    show BackendUrl, backendUrlProvider;

const principal = 'https://tunel.ngrok-free.dev';
const respaldo = 'https://ya-viene-backend.fly.dev';

/// Razón de contraste WCAG entre dos colores opacos.
double _contraste(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// El color de la letra de un texto, tal como se pinta.
Color _letra(WidgetTester tester, String texto) => tester
    .widget<RichText>(
      find.descendant(of: find.text(texto), matching: find.byType(RichText)),
    )
    .text
    .style!
    .color!;

/// La cabecera sola, al ancho del panel, con la conexión en línea.
Future<ProviderContainer> _montar(
  WidgetTester tester,
  BackendUrl Function() backend,
) async {
  await tester.binding.setSurfaceSize(const Size(1600, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final panel = ProviderContainer(
    overrides: [backendUrlProvider.overrideWith(backend)],
  );
  addTearDown(panel.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: panel,
      child: MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: DashboardHeader(
            connection: FleetConnection.connected,
            onLogout: () {},
          ),
        ),
      ),
    ),
  );
  return panel;
}

void main() {
  testWidgets('en el túnel la cabecera no dice nada del respaldo', (
    tester,
  ) async {
    await _montar(
      tester,
      () => BackendUrl(principal, principal: principal, respaldo: respaldo),
    );

    expect(find.text('En línea'), findsOneWidget);
    expect(find.text('Conectado al respaldo'), findsNothing);
  });

  testWidgets('en el respaldo lo dice, al lado del estado de la conexión', (
    tester,
  ) async {
    await _montar(
      tester,
      () => BackendUrl(respaldo, principal: principal, respaldo: respaldo),
    );

    final linea = find.text('Conectado al respaldo');
    expect(linea, findsOneWidget);
    // No sustituye al estado de la conexión: van los dos, la línea delante.
    expect(find.text('En línea'), findsOneWidget);
    expect(
      tester.getTopRight(linea).dx,
      lessThan(tester.getTopLeft(find.text('En línea')).dx),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'aparece sola cuando el panel se muda al respaldo con la cabecera a la '
    'vista',
    (tester) async {
      final panel = await _montar(
        tester,
        () => BackendUrl(
          principal,
          principal: principal,
          respaldo: respaldo,
          sonda: (url, espera) async => url == respaldo,
        ),
      );
      expect(find.text('Conectado al respaldo'), findsNothing);

      await panel.read(backendUrlProvider.notifier).reResolver();
      await tester.pump();

      expect(find.text('Conectado al respaldo'), findsOneWidget);
    },
  );

  // Salir revoca el token en el servidor para todas las sesiones de la
  // cuenta (T3.10): el botón lo dice antes de pulsarlo.
  testWidgets('Salir avisa de que cierra la sesión en todos los equipos', (
    tester,
  ) async {
    await _montar(
      tester,
      () => BackendUrl(principal, principal: principal, respaldo: respaldo),
    );

    expect(
      find.ancestor(of: find.text('Salir'), matching: find.byType(Tooltip)),
      findsOneWidget,
    );
    expect(
      find.byTooltip('Cierra la sesión en todos los equipos con esta cuenta'),
      findsOneWidget,
    );
  });

  // El dueño pidió la cabecera en el degradado del login (2026-10-07). La
  // letra va encima de todo el ancho, así que se mide contra el borde más
  // claro que se ve, no contra el azul de la izquierda.
  testWidgets('la cabecera va en el degradado del login y se lee en todo él', (
    tester,
  ) async {
    await _montar(
      tester,
      () => BackendUrl(respaldo, principal: principal, respaldo: respaldo),
    );

    final caja = tester.widget<Container>(
      find.byKey(const ValueKey('cabecera')),
    );
    final g = (caja.decoration! as BoxDecoration).gradient! as LinearGradient;
    expect(g.colors, const [Color(0xFF17325F), Color(0xFF00A859)]);
    final inicio = g.begin as Alignment, fin = g.end as Alignment;
    Color en(double x) => Color.lerp(
      g.colors.first,
      g.colors.last,
      ((x - inicio.x) / (fin.x - inicio.x)).clamp(0.0, 1.0),
    )!;
    final claro = [
      en(-1),
      en(1),
    ].reduce((a, b) => a.computeLuminance() > b.computeLuminance() ? a : b);

    for (final texto in [
      'YA VIENE',
      'CONTROL DE FLOTA',
      'Conectado al respaldo',
      'Salir',
    ]) {
      expect(
        _contraste(_letra(tester, texto), claro),
        greaterThanOrEqualTo(4.5),
        reason: '«$texto» sobre el borde claro del degradado',
      );
    }

    // El estado va en su píldora, opaca: su color no compite con el verde.
    final pildora = tester
        .widgetList<Container>(
          find.ancestor(
            of: find.text('En línea'),
            matching: find.byType(Container),
          ),
        )
        .map((c) => c.decoration)
        .whereType<BoxDecoration>()
        .firstWhere((d) => d.color != null)
        .color!;
    expect(pildora.a, 1.0);
    expect(
      _contraste(_letra(tester, 'En línea'), pildora),
      greaterThanOrEqualTo(4.5),
    );
  });
}
