import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import 'package:ya_viene_pasajero/core/widgets/aviso.dart';
import 'package:ya_viene_pasajero/core/widgets/dialogo.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/alert_toggle_provider.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/tracking_providers.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/user_location_provider.dart';
import 'package:ya_viene_pasajero/features/map/presentation/widgets/eta_bottom_sheet.dart';

/// Los avisos de la hoja con diseño propio (dueño, 2026-09-28: «los pop ups
/// y warning en todas las apps deben ser con diseño propio»). Lo que la
/// regla rechaza sale en la tarjeta de aviso de la app, no en el SnackBar de
/// fábrica con su acción de texto; el permiso de notificaciones negado es
/// una pregunta con salida, así que va en el `Dialogo` de la app.
class _TestUserLocation extends UserLocationNotifier {
  void set(UserLocationState state) => this.state = state;
}

class _ToggleFijo extends AlertToggleController {
  _ToggleFijo(super.ref, this.resultado);

  final AlertToggleResult resultado;

  @override
  Future<AlertToggleResult> toggle(String busId) async => resultado;
}

void main() {
  Future<ProviderContainer> montar(
    WidgetTester tester,
    AlertToggleResult resultado,
  ) async {
    final container = ProviderContainer(overrides: [
      userLocationProvider.overrideWith((ref) => _TestUserLocation()),
      // Bus a ~5 km: lejos del radio, el botón queda libre para tocarlo.
      busPositionsSourceProvider.overrideWith(
        (ref, routeId) => Stream.value([
          BusPosition(
            busId: 'A-1',
            routeId: 'R1',
            lat: 6.29,
            lon: -75.5812,
            heading: 0,
            speedKmh: 20,
            timestamp: DateTime.now(),
            isGhostBus: false,
          ),
        ]),
      ),
      alertToggleProvider.overrideWith((ref) => _ToggleFijo(ref, resultado)),
    ]);
    addTearDown(container.dispose);
    container.listen(selectedRouteProvider, (_, __) {});
    (container.read(userLocationProvider.notifier) as _TestUserLocation).set(
      const UserLocationState(
        mode: UserLocationMode.manual,
        lat: 6.2442,
        lon: -75.5812,
      ),
    );
    container.read(selectedRouteProvider.notifier).select(
          const RouteInfo(id: 'R1', name: 'Ruta 1', companyId: 'C1'),
        );
    container.read(selectedBusesProvider.notifier).toggleBus('A-1');
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: EtaBottomSheet())),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Avisarme cuando esté cerca'));
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('lo que la regla rechaza sale en la tarjeta de aviso', (
    tester,
  ) async {
    await montar(
      tester,
      const AlertToggleResult(
        AlertToggleOutcome.rejected,
        message: 'Ya tienes 2 avisos activos',
      ),
    );

    final aviso = find.byType(AvisoTarjeta);
    expect(aviso, findsOneWidget);
    expect(
      find.descendant(
        of: aviso,
        matching: find.text('Ya tienes 2 avisos activos'),
      ),
      findsOneWidget,
    );
    // El SnackBar solo presta su cola y su voz: su fondo es transparente
    // y la tarjeta es la que se ve.
    final snack = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(snack.backgroundColor, Colors.transparent);
    expect(snack.elevation, 0);
  });

  testWidgets('sin permiso de notificaciones pregunta en el Dialogo', (
    tester,
  ) async {
    await montar(
      tester,
      const AlertToggleResult(AlertToggleOutcome.permissionDenied),
    );

    expect(find.byType(Dialogo), findsOneWidget);
    expect(find.text('Activa las notificaciones'), findsOneWidget);
    expect(find.text('Abrir Ajustes'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);

    await tester.tap(find.text('Ahora no'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialogo), findsNothing);
  });

  testWidgets('la tarjeta de aviso se oye entera y se va sola', (
    tester,
  ) async {
    final semantica = tester.ensureSemantics();
    await montar(
      tester,
      const AlertToggleResult(
        AlertToggleOutcome.rejected,
        message: 'Ya tienes 2 avisos activos',
      ),
    );

    expect(
      find.bySemanticsLabel(RegExp('Ya tienes 2 avisos activos')),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 8));
    await tester.pumpAndSettle();
    expect(find.byType(AvisoTarjeta), findsNothing);
    semantica.dispose();
  });

  // El globo del Tooltip también es un «pop up»: salía en el gris de
  // fábrica con esquinas de 4, lo único de la pantalla que no era de la
  // app.
  testWidgets('el globo de ayuda va en la tinta del menú, no en el gris', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const Scaffold(
          body: Center(child: Tooltip(message: 'Hola', child: Text('x'))),
        ),
      ),
    );
    await tester.longPress(find.text('x'));
    await tester.pumpAndSettle();

    final globo = tester.widget<Container>(
      find.ancestor(of: find.text('Hola'), matching: find.byType(Container))
          .first,
    );
    final fondo = globo.decoration! as BoxDecoration;
    expect(fondo.color, AppColors.ink);
    expect(fondo.borderRadius, isNot(BorderRadius.circular(4)));
  });

  test('ningún archivo de lib/ abre un diálogo o un aviso de fábrica', () {
    final fuera = <String>[];
    final fabrica = RegExp(
      r'\bAlertDialog\(|\bshowDialog\b|\bSimpleDialog\('
      r'|\bCupertinoAlertDialog\(',
    );
    final barra = RegExp(r'\bSnackBar\(');
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final texto = f.readAsStringSync();
      if (fabrica.hasMatch(texto)) fuera.add(f.path);
      // El único SnackBar es el que presta su cola a `AvisoTarjeta`.
      if (barra.hasMatch(texto) && !f.path.endsWith('aviso.dart')) {
        fuera.add(f.path);
      }
    }
    expect(fuera, isEmpty);
  });
}
