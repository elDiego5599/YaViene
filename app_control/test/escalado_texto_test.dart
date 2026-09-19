// El panel respeta el tamaño de letra del sistema, con tope (T6.3).
//
// Windows deja subir el texto hasta el 225 % y el panel lo tomaba entero.
// Nada desbordaba, pero a 3× el nombre del conductor de una fila queda en
// 47 de sus 462 puntos y solo se leen los puntos suspensivos. Ahora
// `main.dart` lo recorta a 2.0×, como el pasajero, y estas pruebas fijan el
// tope y que a 1.0×, 1.5× y 2.0× nada desborda.
//
// Miden con la tipografía de la app, no con Ahem (ver
// fleet_list_tile_test.dart): aquí se prueba justo si las cosas caben.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_control/core/theme/app_theme.dart';
import 'package:ya_viene_control/features/fleet/domain/fleet_bus.dart';
import 'package:ya_viene_control/features/fleet/presentation/providers/fleet_providers.dart';
import 'package:ya_viene_control/features/fleet/presentation/screens/dashboard_screen.dart';
import 'package:ya_viene_control/features/fleet/presentation/widgets/fleet_list_tile.dart';
import 'package:ya_viene_control/main.dart';
import 'package:ya_viene_core/core/providers/app_providers.dart'
    show BackendUrl, backendUrlProvider;

final _conBackend = [
  backendUrlProvider.overrideWith(() => BackendUrl.fija('http://localhost:3000')),
];

// Una pantalla de portátil corriente, no la del Mac donde se trabaja.
const _portatil = Size(1366, 768);

/// La lista es un cuarto de la pantalla; la cuenta está explicada en
/// fleet_list_tile_test.dart.
final _fila = (_portatil.width - 16 * 2 - 12) / 4 - 2 - 24;

Future<void> _cargarFuentes() async {
  final manifiesto = json.decode(
    await rootBundle.loadString('FontManifest.json'),
  ) as List<dynamic>;
  for (final entrada in manifiesto.cast<Map<String, dynamic>>()) {
    final cargador = FontLoader(entrada['family'] as String);
    final fuentes = (entrada['fonts'] as List).cast<Map<String, dynamic>>();
    for (final fuente in fuentes) {
      cargador.addFont(rootBundle.load(fuente['asset'] as String));
    }
    await cargador.load();
  }
}

void main() {
  setUpAll(_cargarFuentes);

  testWidgets('el texto del sistema a 3× llega al panel recortado a 2×',
      (tester) async {
    await tester.binding.setSurfaceSize(_portatil);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    tester.platformDispatcher.textScaleFactorTestValue = 3.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(
      ProviderScope(overrides: _conBackend, child: const YaVieneControlApp()),
    );
    await tester.pumpAndSettle();

    final contexto = tester.element(find.byType(Scaffold).first);
    expect(MediaQuery.textScalerOf(contexto).scale(10), 20);
  });

  for (final escala in [1.0, 1.5, 2.0]) {
    testWidgets('a $escala× el login cabe sin desbordes', (tester) async {
      await tester.binding.setSurfaceSize(_portatil);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      tester.platformDispatcher.textScaleFactorTestValue = escala;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await tester.pumpWidget(
        ProviderScope(overrides: _conBackend, child: const YaVieneControlApp()),
      );
      await tester.pumpAndSettle();

      expect(find.text('INGRESAR'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a $escala× la cabecera del panel cabe sin desbordes',
        (tester) async {
      await tester.binding.setSurfaceSize(_portatil);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      tester.platformDispatcher.textScaleFactorTestValue = escala;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await tester.pumpWidget(
        ProviderScope(
          overrides: _conBackend,
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

      expect(find.text('En línea'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a $escala× la fila de un bus cabe sin desbordes',
        (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = escala;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: ListView(
              children: [
                Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: _fila,
                    child: FleetListTile(
                      bus: const FleetBus(
                        busId: 'WWW-000',
                        companyId: 'empresa',
                        placa: 'WWW-000',
                        driverName: 'Conductor de nombre largo',
                        visible: true,
                        online: true,
                        isGhost: false,
                      ),
                      selected: false,
                      updating: false,
                      routeName: 'Vivero Paraíso',
                      onTap: () {},
                      onToggle: (_) {},
                      onEdit: () {},
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    }, variant: const TargetPlatformVariant(
      <TargetPlatform>{TargetPlatform.macOS, TargetPlatform.windows},
    ));
  }
}
