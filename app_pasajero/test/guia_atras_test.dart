import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/guia_atras.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/map_tour_provider.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/map_view_state.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/selected_buses_provider.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/user_location_provider.dart';

class _Ubicacion extends StateNotifier<UserLocationState>
    implements UserLocationNotifier {
  _Ubicacion(super.state);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

const _conPunto = UserLocationState(
  mode: UserLocationMode.gps,
  lat: 11.0041,
  lon: -74.8070,
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  /// Una guía puesta en [paso], con o sin el de la ubicación.
  Future<ProviderContainer> guiaEn(
    MapGuideStep paso, {
    bool incluyeUbicacion = false,
    UserLocationState ubicacion = _conPunto,
  }) async {
    final guia = MapGuideNotifier();
    await guia.initialize(
      hasLocation: !incluyeUbicacion,
      locationSettled: true,
      hasRoute: false,
      hasSelectedBus: false,
      hasActiveAlert: false,
    );
    await guia.empezar();
    await guia.moveTo(paso);
    final container = ProviderContainer(overrides: [
      mapGuideProvider.overrideWith((ref) => guia),
      userLocationProvider.overrideWith((ref) => _Ubicacion(ubicacion)),
    ]);
    addTearDown(container.dispose);
    container.listen(pedirSelectorProvider, (_, __) {});
    return container;
  }

  group('pasoAnterior', () {
    test('cada paso vuelve al de antes', () {
      const guia = MapGuideState(step: MapGuideStep.alert, initialized: true);
      for (final (desde, hasta) in [
        (MapGuideStep.company, MapGuideStep.search),
        (MapGuideStep.route, MapGuideStep.company),
        (MapGuideStep.launchBuses, MapGuideStep.route),
        (MapGuideStep.buses, MapGuideStep.launchBuses),
        (MapGuideStep.distance, MapGuideStep.buses),
        (MapGuideStep.alert, MapGuideStep.distance),
        (MapGuideStep.background, MapGuideStep.alert),
      ]) {
        expect(pasoAnterior(guia, desde, hayPunto: true), hasta,
            reason: '$desde');
      }
    });

    test('el primer paso no tiene a dónde volver', () {
      const sinUbicacion = MapGuideState(
          step: MapGuideStep.search,
          initialized: true,
          includesLocation: false);
      expect(pasoAnterior(sinUbicacion, MapGuideStep.search, hayPunto: true),
          isNull);
      const conUbicacion =
          MapGuideState(step: MapGuideStep.location, initialized: true);
      expect(pasoAnterior(conUbicacion, MapGuideStep.location, hayPunto: false),
          isNull);
    });

    // Con el GPS puesto, volver a «Fija tu punto» rebotaba al instante: la
    // siguiente lectura del GPS lo daba por hecho y la guía saltaba otra vez
    // a la búsqueda, y «Atrás» parecía no hacer nada.
    test('con el punto ya puesto no se vuelve a pedir el punto', () {
      const guia = MapGuideState(step: MapGuideStep.search, initialized: true);
      expect(pasoAnterior(guia, MapGuideStep.search, hayPunto: true), isNull);
      expect(pasoAnterior(guia, MapGuideStep.search, hayPunto: false),
          MapGuideStep.location);
    });
  });

  group('volverEnGuia', () {
    // «Toca un bus» con el bus todavía elegido: tocarlo lo soltaba en vez
    // de elegirlo, y la guía no avanzaba.
    test('de la distancia a los buses suelta el bus elegido', () async {
      final c = await guiaEn(MapGuideStep.distance);
      c.read(selectedBusesProvider.notifier).toggleBus('BUS-1');

      await volverEnGuia(c.read, MapGuideStep.distance);

      expect(c.read(mapGuideProvider).step, MapGuideStep.buses);
      expect(c.read(selectedBusesProvider), isEmpty);
    });

    // «Muestra los buses» vive en el selector, que ya estaba cerrado: la
    // guía quedaba en un paso que no se veía en ninguna parte.
    test('de los buses a «Ver buses en vivo» vuelve a abrir el selector',
        () async {
      final c = await guiaEn(MapGuideStep.buses);
      final antes = c.read(pedirSelectorProvider);

      await volverEnGuia(c.read, MapGuideStep.buses);

      expect(c.read(mapGuideProvider).step, MapGuideStep.launchBuses);
      expect(c.read(pedirSelectorProvider), antes + 1);
    });

    test('sin paso anterior no toca nada', () async {
      final c = await guiaEn(MapGuideStep.search);

      await volverEnGuia(c.read, MapGuideStep.search);

      expect(c.read(mapGuideProvider).step, MapGuideStep.search);
    });

    test('los demás pasos solo cambian de paso', () async {
      final c = await guiaEn(MapGuideStep.alert);
      c.read(selectedBusesProvider.notifier).toggleBus('BUS-1');
      final antes = c.read(pedirSelectorProvider);

      await volverEnGuia(c.read, MapGuideStep.alert);

      expect(c.read(mapGuideProvider).step, MapGuideStep.distance);
      expect(c.read(selectedBusesProvider), {'BUS-1'});
      expect(c.read(pedirSelectorProvider), antes);
    });
  });
}
