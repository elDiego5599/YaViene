import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/route_reach_provider.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/user_location_provider.dart';
import 'package:ya_viene_pasajero/features/map/presentation/widgets/alert_guards.dart';
import 'package:ya_viene_pasajero/features/notifications/presentation/providers/proximity_alerts_provider.dart'
    show alertRadiusMeters;

class _TestUserLocation extends UserLocationNotifier {
  void set(UserLocationState state) => this.state = state;
}

const _userLat = 6.2442;
const _userLon = -75.5812;
const _metersPerDegree = 111194.9;

BusPosition _bus({bool ghost = false}) => BusPosition(
      busId: 'A-1',
      routeId: 'R1',
      lat: _userLat,
      lon: _userLon,
      heading: 0,
      speedKmh: 30,
      timestamp: DateTime.now(),
      isGhostBus: ghost,
    );

/// Un tramo recto norte-sur que pasa a [km] del usuario.
List<GeoPoint> _routeAtKm(double km) {
  final lat = _userLat + (km * 1000) / _metersPerDegree;
  return [
    GeoPoint(lat: lat, lon: _userLon - 0.05),
    GeoPoint(lat: lat, lon: _userLon + 0.05),
  ];
}

void main() {
  group('validateAlertActivation: ruta que no pasa cerca', () {
    String? validate({double? routeDistanceMeters, bool ghost = false}) =>
        validateAlertActivation(
          hasPosition: true,
          bus: _bus(ghost: ghost),
          busAlreadyNear: false,
          activeAlertsCount: 0,
          routeDistanceMeters: routeDistanceMeters,
        );

    test('rechaza el aviso si el recorrido no entra en el radio de disparo',
        () {
      expect(validate(routeDistanceMeters: 3400),
          contains('Esta ruta no pasa cerca de ti'));
      expect(validate(routeDistanceMeters: 3400), contains('3.4 km'));
    });

    // El bug que reportó el usuario: el recorrido rozaba el anillo verde de
    // 2 km y la app dejaba armar el aviso, pero el aviso solo suena a 1 km.
    // El botón decía «AVISO ACTIVADO» y no iba a sonar nunca.
    test('entre 1 y 2 km ya no se puede armar: ahí no sonaría nunca', () {
      expect(validate(routeDistanceMeters: 1500),
          contains('Esta ruta no pasa cerca de ti'));
      expect(validate(routeDistanceMeters: 1900), isNotNull);
      expect(validate(routeDistanceMeters: 2100), isNotNull);
    });

    test('el tope de la ruta es exactamente el radio que dispara', () {
      expect(alertMaxRouteDistanceMeters, alertRadiusMeters);
    });

    test('a 10 km o más el decimal sobra', () {
      expect(validate(routeDistanceMeters: 12400), contains('12 km'));
    });

    test('justo en el límite todavía deja armar', () {
      // 1000 m es alcanzable: el disparo es `distancia <= alertRadiusMeters`.
      expect(validate(routeDistanceMeters: 1000), isNull);
      expect(validate(routeDistanceMeters: 999), isNull);
      expect(validate(routeDistanceMeters: 1001), isNotNull);
    });

    test('sin dato de distancia se deja armar: la duda no bloquea', () {
      expect(validate(), isNull);
    });

    test('la ruta lejana manda sobre el "sin señal"', () {
      // Decirle "espera a que vuelva a transmitir" sería mentira: ni va a
      // transmitir cerca, ni esperar sirve.
      final message = validate(routeDistanceMeters: 8000, ghost: true);
      expect(message, contains('no pasa cerca'));
      expect(message, isNot(contains('sin señal')));
    });

    test('sin ubicación gana el mensaje de ubicación', () {
      expect(
        validateAlertActivation(
          hasPosition: false,
          bus: _bus(),
          busAlreadyNear: false,
          activeAlertsCount: 0,
          routeDistanceMeters: 8000,
        ),
        contains('dónde estás'),
      );
    });
  });

  group('routeDistanceToUserProvider', () {
    ProviderContainer containerWith({
      required List<GeoPoint> points,
      bool located = true,
    }) {
      final container = ProviderContainer(overrides: [
        userLocationProvider.overrideWith((ref) => _TestUserLocation()),
        routeTrajectoryProvider.overrideWith((ref, routeId) => RouteTrajectory(
              routeId: routeId,
              routeName: 'R1',
              points: points,
            )),
      ]);
      addTearDown(container.dispose);
      if (located) {
        (container.read(userLocationProvider.notifier) as _TestUserLocation)
            .set(const UserLocationState(
          mode: UserLocationMode.manual,
          lat: _userLat,
          lon: _userLon,
        ));
      }
      return container;
    }

    test('mide lo más que se acerca el recorrido', () {
      final container = containerWith(points: _routeAtKm(3));
      expect(
          container.read(routeDistanceToUserProvider('R1')), closeTo(3000, 60));
      expect(container.read(routeTooFarFromUserProvider('R1')), isTrue);
    });

    test('una ruta que pasa al lado no bloquea nada', () {
      final container = containerWith(points: _routeAtKm(0.4));
      expect(container.read(routeTooFarFromUserProvider('R1')), isFalse);
    });

    test('un recorrido a 1.5 km cuenta como lejos', () {
      final container = containerWith(points: _routeAtKm(1.5));
      expect(container.read(routeTooFarFromUserProvider('R1')), isTrue);
    });

    test('sin ubicación no se sabe, y no saber no bloquea', () {
      final container = containerWith(points: _routeAtKm(30), located: false);
      expect(container.read(routeDistanceToUserProvider('R1')), isNull);
      expect(container.read(routeTooFarFromUserProvider('R1')), isFalse);
    });

    test('ruta sin recorrido en rutas.json: tampoco bloquea', () {
      final container = containerWith(points: const []);
      expect(container.read(routeDistanceToUserProvider('R1')), isNull);
      expect(container.read(routeTooFarFromUserProvider('R1')), isFalse);
    });

    test('un solo punto no es una polilínea', () {
      final container =
          containerWith(points: [const GeoPoint(lat: 10, lon: -74)]);
      expect(container.read(routeDistanceToUserProvider('R1')), isNull);
      expect(container.read(routeTooFarFromUserProvider('R1')), isFalse);
    });

    test('geometría degenerada (todos los puntos iguales) no bloquea', () {
      final container = containerWith(points: [
        const GeoPoint(lat: _userLat, lon: _userLon),
        const GeoPoint(lat: _userLat, lon: _userLon),
      ]);
      // Aquí sí hay distancia (0 m): lo que se comprueba es que no explote ni
      // devuelva infinito.
      expect(container.read(routeTooFarFromUserProvider('R1')), isFalse);
    });
  });
}
