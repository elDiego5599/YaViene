import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

import 'package:ya_viene_pasajero/features/map/presentation/providers/eta_provider.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/tracking_providers.dart';
import 'package:ya_viene_pasajero/features/map/presentation/utils/geo.dart';

// Polilínea recta de ~1.113 km en el eje norte-sur (lat 10.90 → 10.91).
final _line = [
  const GeoPoint(lat: 10.9000, lon: -74.8000),
  const GeoPoint(lat: 10.9050, lon: -74.8000),
  const GeoPoint(lat: 10.9100, lon: -74.8000),
];

void main() {
  group('projectOntoPolyline', () {
    test('proyecta puntos sobre el recorrido y mide la distancia acumulada', () {
      final bus = projectOntoPolyline(
          const GeoPoint(lat: 10.9050, lon: -74.8000), _line);
      expect(bus.alongMeters, closeTo(556.6, 5));
      expect(bus.distanceMeters, closeTo(0, 0.5));

      final user = projectOntoPolyline(
          const GeoPoint(lat: 10.9100, lon: -74.8000), _line);
      expect(user.alongMeters, closeTo(1113.2, 5));
    });

    test('un punto fuera del recorrido conserva su distancia', () {
      final off = projectOntoPolyline(
          const GeoPoint(lat: 10.9075, lon: -74.7990), _line);
      expect(off.alongMeters, closeTo(834.9, 5));
      expect(off.distanceMeters, closeTo(111.3, 5));
    });
  });

  group('computeEta', () {
    test('calcula minutos según la distancia restante y la velocidad', () {
      final eta = computeEta(
        points: _line,
        busLat: 10.9050,
        busLon: -74.8000,
        userLat: 10.9100,
        userLon: -74.8000,
        speedKmh: 40,
        sentido: 'ida',
      );
      expect(eta!.state, EtaState.enRuta);
      expect(eta.direction, EtaDirection.ida);
      expect(eta.minutes, 1);
      expect(eta.remainingMeters, closeTo(556.6, 5));
    });

    test('tráncón: velocidad baja → estado trancado y ETA más alto', () {
      final eta = computeEta(
        points: _line,
        busLat: 10.9050,
        busLon: -74.8000,
        userLat: 10.9100,
        userLon: -74.8000,
        speedKmh: 5,
        sentido: 'ida',
      );
      expect(eta!.state, EtaState.trancado);
      expect(eta.minutes, greaterThanOrEqualTo(7));
    });

    test('detenido: bus sin moverse → no hay minutos', () {
      final eta = computeEta(
        points: _line,
        busLat: 10.9050,
        busLon: -74.8000,
        userLat: 10.9100,
        userLon: -74.8000,
        speedKmh: 0,
        sentido: 'ida',
      );
      expect(eta!.state, EtaState.detenido);
      expect(eta.minutes, isNull);
    });

    test('bus de ida que ya pasó al usuario → yaPaso', () {
      final eta = computeEta(
        points: _line,
        busLat: 10.9100,
        busLon: -74.8000,
        userLat: 10.9050,
        userLon: -74.8000,
        speedKmh: 40,
        sentido: 'ida',
      );
      expect(eta!.state, EtaState.yaPaso);
      expect(eta.direction, EtaDirection.ida);
      expect(eta.minutes, isNull);
    });

    test('bus de venida entre el usuario y el final del recorrido → viene', () {
      // Bus de venida: está MÁS ALLÁ del usuario en el trazado (a punto de
      // girar y regresar). Con lógica de ida diría "ya pasó", pero viene.
      final eta = computeEta(
        points: _line,
        busLat: 10.9100,
        busLon: -74.8000,
        userLat: 10.9050,
        userLon: -74.8000,
        speedKmh: 40,
        sentido: 'venida',
      );
      expect(eta!.state, EtaState.enRuta);
      expect(eta.direction, EtaDirection.venida);
      expect(eta.minutes, 1);
      expect(eta.remainingMeters, closeTo(556.6, 5));
    });

    test('bus de venida que ya pasó (quedó detrás del usuario) → yaPaso', () {
      final eta = computeEta(
        points: _line,
        busLat: 10.9050,
        busLon: -74.8000,
        userLat: 10.9100,
        userLon: -74.8000,
        speedKmh: 40,
        sentido: 'venida',
      );
      expect(eta!.state, EtaState.yaPaso);
      expect(eta.direction, EtaDirection.venida);
      expect(eta.minutes, isNull);
    });

    test('bus de ida viniendo hacia el usuario → enRuta', () {
      final eta = computeEta(
        points: _line,
        busLat: 10.9050,
        busLon: -74.8000,
        userLat: 10.9100,
        userLon: -74.8000,
        speedKmh: 40,
        sentido: 'ida',
      );
      expect(eta!.state, EtaState.enRuta);
      expect(eta.direction, EtaDirection.ida);
    });

    test('ruta con subida antes de devolverse: el sentido gana, no el rumbo', () {
      // Polilínea: sube (10.9050 → 10.9100) y luego baja (10.9100 → 10.9055)
      // para devolverse. El bus de venida va en esa bajada con rumbo opuesto
      // al que tendría en ida — pero reporta 'venida' y ESO define el ETA.
      final zigzag = [
        const GeoPoint(lat: 10.9000, lon: -74.8000),
        const GeoPoint(lat: 10.9050, lon: -74.8000),
        const GeoPoint(lat: 10.9100, lon: -74.8000),
        const GeoPoint(lat: 10.9055, lon: -74.8000),
      ];
      // Bus en 10.9090 (bajando para devolverse, venida), usuario en 10.9030.
      // De venida le faltan ~1224 m; de ida (mal) diría "ya pasó".
      final eta = computeEta(
        points: zigzag,
        busLat: 10.9090,
        busLon: -74.8000,
        userLat: 10.9030,
        userLon: -74.8000,
        speedKmh: 40,
        sentido: 'venida',
      );
      expect(eta!.state, EtaState.enRuta);
      expect(eta.direction, EtaDirection.venida);
      expect(eta.minutes, 2);
    });

    test('sin sentido reportado (dispositivo antiguo) → se asume ida', () {
      final eta = computeEta(
        points: _line,
        busLat: 10.9100,
        busLon: -74.8000,
        userLat: 10.9050,
        userLon: -74.8000,
        speedKmh: 40,
        sentido: null,
      );
      expect(eta!.direction, EtaDirection.desconocido);
      expect(eta.state, EtaState.yaPaso);
    });

    test('geometría insuficiente → null', () {
      final eta = computeEta(
        points: const [GeoPoint(lat: 10.9, lon: -74.8)],
        busLat: 10.9050,
        busLon: -74.8000,
        userLat: 10.9100,
        userLon: -74.8000,
        speedKmh: 40,
        sentido: 'ida',
      );
      expect(eta, isNull);
    });
  });

  group('SelectedBusesNotifier (selección única)', () {
    test('tocar otro bus reemplaza la selección', () {
      final notifier = SelectedBusesNotifier();
      notifier.toggleBus('B-1');
      expect(notifier.state, {'B-1'});
      notifier.toggleBus('B-2');
      expect(notifier.state, {'B-2'});
    });

    test('tocar el mismo bus deselecciona', () {
      final notifier = SelectedBusesNotifier();
      notifier.toggleBus('B-1');
      notifier.toggleBus('B-1');
      expect(notifier.state, isEmpty);
    });
  });
}
