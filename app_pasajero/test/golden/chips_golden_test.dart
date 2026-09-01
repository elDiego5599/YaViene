import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/'
    'realtime_providers.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/'
    'user_location_provider.dart';
import 'package:ya_viene_pasajero/features/map/presentation/widgets/'
    'idle_status_chip.dart';
import 'package:ya_viene_pasajero/features/map/presentation/widgets/'
    'location_status_chip.dart';
import 'package:ya_viene_pasajero/features/map/presentation/widgets/'
    'map_placeholders.dart';

import 'golden_harness.dart';

/// Lo que flota encima del mapa: las píldoras de estado y las dos pantallas
/// de respaldo de cuando el mapa no llega.
///
/// Son diez iconos que hoy rompen la familia `_rounded` y tres estilos de
/// texto escritos a mano. Se retratan ahora, antes de tocarlos.
class _UbicacionFija extends UserLocationNotifier {
  _UbicacionFija(UserLocationState inicial) {
    state = inicial;
  }
}

UserLocationState _estado(UserLocationMode modo) => UserLocationState(
      mode: modo,
      lat: modo == UserLocationMode.locating ? null : 10.99,
      lon: modo == UserLocationMode.locating ? null : -74.79,
      updatedAt: DateTime(2026),
    );

void main() {
  Future<void> montarChip(
    WidgetTester tester,
    UserLocationMode modo, {
    bool pinAprendido = true,
  }) async {
    SharedPreferences.setMockInitialValues(
      pinAprendido ? {'pin_drag_learned': true} : {},
    );
    final container = ProviderContainer(overrides: [
      userLocationProvider.overrideWith((ref) => _UbicacionFija(_estado(modo))),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: marcoGolden(
          const ColoredBox(
            color: Color(0xFFE8E6E1),
            child: Center(child: LocationStatusChip()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final (modo, nombre) in const [
    (UserLocationMode.locating, 'localizando'),
    (UserLocationMode.gps, 'gps'),
    (UserLocationMode.manual, 'manual'),
    (UserLocationMode.denied, 'sin_permiso'),
    (UserLocationMode.permanentDenied, 'bloqueada'),
    (UserLocationMode.gpsFailed, 'gps_fallido'),
  ]) {
    testWidgets('píldora de ubicación · $nombre', (tester) async {
      fijarPantalla(tester);
      await montarChip(tester, modo);
      await coincideConOro(tester, 'chip_ubicacion_$nombre');
    });
  }

  testWidgets('píldora de ubicación · manual con la pista del pin',
      (tester) async {
    fijarPantalla(tester);
    await montarChip(tester, UserLocationMode.manual, pinAprendido: false);
    await coincideConOro(tester, 'chip_ubicacion_manual_con_pista');
  });

  for (final (estado, nombre) in const [
    (ConnectionStatus.disconnected, 'sin_conexion'),
    (ConnectionStatus.reconnecting, 'reconectando'),
  ]) {
    testWidgets('píldora de conexión · $nombre', (tester) async {
      fijarPantalla(tester);
      final container = ProviderContainer(overrides: [
        connectionStateProvider.overrideWith((ref) => Stream.value(estado)),
      ]);
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: marcoGolden(
            const ColoredBox(
              color: Color(0xFFE8E6E1),
              child: Center(child: IdleStatusChip()),
            ),
          ),
        ),
      );
      // `PulsingDot` late para siempre: `pumpAndSettle` no terminaría nunca.
      // Un salto fijo desde el arranque deja el punto en la misma fase en
      // cada corrida.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await coincideConOro(tester, 'chip_conexion_$nombre');
    });
  }

  testWidgets('mapa preparándose', (tester) async {
    fijarPantalla(tester);
    await tester.pumpWidget(marcoGolden(
      MapStylePlaceholder(
        layersReady: false,
        placeholderShown: true,
        onFadeEnd: () {},
      ),
    ));
    await tester.pumpAndSettle();
    await coincideConOro(tester, 'mapa_preparandose');
  });

  testWidgets('mapa que no cargó', (tester) async {
    fijarPantalla(tester);
    await tester.pumpWidget(marcoGolden(
      Stack(children: [
        const Positioned.fill(child: ColoredBox(color: Color(0xFFE8E6E1))),
        MapStyleFailedBanner(styleFailed: true, onRetry: () {}),
      ]),
    ));
    await tester.pumpAndSettle();
    await coincideConOro(tester, 'mapa_fallido');
  });
}
