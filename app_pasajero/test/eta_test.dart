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
      );
      expect(eta!.state, EtaState.enRuta);
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
      );
      expect(eta!.state, EtaState.detenido);
      expect(eta.minutes, isNull);
    });

    test('el bus ya pasó al usuario → yaPaso', () {
      final eta = computeEta(
        points: _line,
        busLat: 10.9100,
        busLon: -74.8000,
        userLat: 10.9050,
        userLon: -74.8000,
        speedKmh: 40,
      );
      expect(eta!.state, EtaState.yaPaso);
      expect(eta.minutes, isNull);
    });

    test('geometría insuficiente → null', () {
      final eta = computeEta(
        points: const [GeoPoint(lat: 10.9, lon: -74.8)],
        busLat: 10.9050,
        busLon: -74.8000,
        userLat: 10.9100,
        userLon: -74.8000,
        speedKmh: 40,
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
