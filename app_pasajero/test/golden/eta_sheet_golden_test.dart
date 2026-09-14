import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/'
    'tracking_providers.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/'
    'user_location_provider.dart';
import 'package:ya_viene_pasajero/features/map/presentation/widgets/'
    'eta_bottom_sheet.dart';
import 'package:ya_viene_pasajero/features/notifications/presentation/'
    'providers/proximity_alerts_provider.dart';

import 'golden_harness.dart';

/// La hoja de distancia en sus cuatro caras.
///
/// Es la pantalla con el número más grande de la app y la que más estilos
/// escritos a mano tiene (ocho). Si la migración de tipografía se pasa de
/// frenada, se nota aquí primero.
class _UbicacionDePrueba extends UserLocationNotifier {
  void fijar(UserLocationState estado) => state = estado;
}

const double _lat = 6.2442;
const double _lon = -75.5812;

RouteInfo _ruta() => const RouteInfo(id: 'R1', name: 'Ruta 1', companyId: 'C1');

BusPosition _busA(double desfase) => BusPosition(
      busId: 'A-1',
      routeId: 'R1',
      lat: _lat + desfase,
      lon: _lon,
      heading: 0,
      speedKmh: 30,
      // Fecha fija: la hoja no la muestra, pero un `DateTime.now()` haría
      // que dos corridas no fueran comparables si algún día la mostrara.
      timestamp: DateTime(2026, 1, 1, 8),
      isGhostBus: false,
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<ProviderContainer> montar(
    WidgetTester tester, {
    required List<BusPosition> buses,
    bool conUbicacion = true,
    bool enRespaldo = false,
  }) async {
    final container = ProviderContainer(overrides: [
      userLocationProvider.overrideWith((ref) => _UbicacionDePrueba()),
      busPositionsSourceProvider.overrideWith(
        (ref, routeId) => Stream.value(buses),
      ),
      routeTrajectoryProvider.overrideWith(
        (ref, routeId) => RouteTrajectory(
          routeId: routeId,
          routeName: 'Ruta 1',
          points: const [
            GeoPoint(lat: _lat, lon: _lon - 0.05),
            GeoPoint(lat: _lat, lon: _lon + 0.05),
          ],
        ),
      ),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: marcoGolden(
          // Abajo del todo, como en el mapa (`map_screen.dart:360-364`):
          // así la foto también vigila el respeto al área segura inferior.
          ColoredBox(
            color: const Color(0xFFE8E6E1),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: EtaBottomSheet(enRespaldo: enRespaldo),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    if (conUbicacion) {
      (container.read(userLocationProvider.notifier) as _UbicacionDePrueba)
          .fijar(const UserLocationState(
        mode: UserLocationMode.manual,
        lat: _lat,
        lon: _lon,
      ));
    }
    container.read(selectedRouteProvider.notifier).select(_ruta());
    container.read(selectedBusesProvider.notifier).toggleBus('A-1');
    await tester.pump();
    // El `AnimatedSwitcher` de la hoja tarda; con un salto fijo la foto
    // sale siempre en el mismo fotograma.
    await tester.pump(const Duration(milliseconds: 400));
    // Y otro tanto para el alto: la hoja lo sigue con `AnimatedSize`, y la
    // tarjeta del bus termina de rellenarse —distancia, unidad, botón— un
    // fotograma después de elegirlo, así que esa animación arranca tarde.
    await tester.pump(const Duration(milliseconds: 400));
    return container;
  }

  testWidgets('hoja · metros', (tester) async {
    fijarPantalla(tester);
    await montar(tester, buses: [_busA(0.007645)]);
    await coincideConOro(tester, 'hoja_metros');
  });

  testWidgets('hoja · kilómetros', (tester) async {
    fijarPantalla(tester);
    await montar(tester, buses: [_busA(0.02)]);
    await coincideConOro(tester, 'hoja_kilometros');
  });

  testWidgets('hoja · sin ubicación', (tester) async {
    fijarPantalla(tester);
    await montar(tester, buses: [_busA(0.007645)], conUbicacion: false);
    await coincideConOro(tester, 'hoja_sin_ubicacion');
  });

  testWidgets('hoja · con aviso activo', (tester) async {
    fijarPantalla(tester);
    final container = await montar(tester, buses: [_busA(0.02)]);
    container.read(activeAlertsProvider.notifier).toggleAlert('A-1');
    container.read(proximityAlertsProvider.notifier).armAlert('A-1', 'R1');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await coincideConOro(tester, 'hoja_con_aviso');
  });

  testWidgets('hoja · el bus ya está cerca', (tester) async {
    fijarPantalla(tester);
    await montar(tester, buses: [_busA(0.002)]);
    await coincideConOro(tester, 'hoja_bus_cerca');
  });

  // La misma hoja con el texto del sistema al 130%. No es un capricho de
  // accesibilidad: es la pantalla con el número de 44 px y tres líneas de
  // apoyo, y es donde primero se desborda algo si la Fase 2 sube un
  // tamaño. Sin esta foto, el desbordamiento aparece en el teléfono de
  // alguien y no en el CI.
  testWidgets('hoja · texto al 130%', (tester) async {
    fijarPantalla(tester, escalaTexto: 1.3);
    await montar(tester, buses: [_busA(0.007645)]);
    await coincideConOro(tester, 'hoja_metros_texto_grande');
  });

  // En el respaldo (T2.3), con la tarjeta del bus, que es la cara más alta
  // de la hoja. Al 100% y al 200%, que es el techo de la hoja: si la línea
  // de más no cupiera ahí, se desbordaría aquí y no en un teléfono.
  testWidgets('hoja · en el respaldo', (tester) async {
    fijarPantalla(tester);
    await montar(tester, buses: [_busA(0.007645)], enRespaldo: true);
    await coincideConOro(tester, 'hoja_respaldo');
  });

  testWidgets('hoja · en el respaldo, texto al 200%', (tester) async {
    fijarPantalla(tester, escalaTexto: 2.0);
    await montar(tester, buses: [_busA(0.007645)], enRespaldo: true);
    await coincideConOro(tester, 'hoja_respaldo_texto_doble');
  });
}
