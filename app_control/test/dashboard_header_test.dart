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
  testWidgets('la cabecera es blanca y su texto se lee', (tester) async {
    await _montar(
      tester,
      () => BackendUrl(respaldo, principal: principal, respaldo: respaldo),
    );

    // El degradado del login se probó y no gustó (dueño, 2026-10-07).
    final caja = tester.widget<Container>(
      find.byKey(const ValueKey('cabecera')),
    );
    final deco = caja.decoration! as BoxDecoration;
    expect(deco.gradient, isNull);
    expect(deco.color, AppColors.surface);

    for (final texto in [
      'Reportes',
      'Conectado al respaldo',
      'Salir',
      'En línea',
    ]) {
      expect(
        _contraste(_letra(tester, texto), AppColors.surface),
        greaterThanOrEqualTo(4.5),
        reason: '«$texto» sobre la cabecera blanca',
      );
    }
  });

  // El rótulo «YA VIENE / CONTROL DE FLOTA» se va y en su sitio quedan dos
  // pestañas como el segmentado de macOS (dueño, 2026-10-26): la elegida en
  // tinta sobre su lámina blanca; la otra, gris secundario sobre el riel.
  testWidgets('la cabecera lleva Flota y Reportes como pestañas', (
    tester,
  ) async {
    await _montar(
      tester,
      () => BackendUrl(principal, principal: principal, respaldo: respaldo),
    );

    expect(find.text('YA VIENE'), findsNothing);
    expect(find.text('CONTROL DE FLOTA'), findsNothing);
    expect(find.byKey(const ValueKey('pestana-flota')), findsOneWidget);
    expect(find.byKey(const ValueKey('pestana-reportes')), findsOneWidget);
    expect(_letra(tester, 'Flota'), AppColors.textPrimary);
    expect(_letra(tester, 'Reportes'), AppColors.textSecondary);
    expect(
      _contraste(AppColors.textPrimary, AppColors.surface),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      _contraste(AppColors.textSecondary, AppColors.surfaceRaised),
      greaterThanOrEqualTo(4.5),
    );
    // Van a la izquierda, donde estaba el rótulo, y del mismo alto.
    final flota = tester.getRect(find.byKey(const ValueKey('pestana-flota')));
    final reportes = tester.getRect(
      find.byKey(const ValueKey('pestana-reportes')),
    );
    expect(flota.left, lessThan(200));
    expect(reportes.left, greaterThan(flota.right - 1));
    expect(reportes.height, flota.height);
    // 34 dentro del riel de 3: los 40 de la cabecera.
    expect(flota.height, greaterThanOrEqualTo(34));
  });
}
