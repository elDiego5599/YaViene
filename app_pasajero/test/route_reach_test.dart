import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/route_reach_provider.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/user_location_provider.dart';
import 'package:ya_viene_pasajero/features/map/presentation/widgets/alert_guards.dart';
import 'package:ya_viene_pasajero/features/notifications/presentation/providers/distancia_aviso_provider.dart';

class _TestUserLocation extends UserLocationNotifier {
  void set(UserLocationState state) => this.state = state;
}

/// La distancia que la persona guardó (o ninguna), sin pasar por el disco.
class _DistanciaFija extends DistanciaAvisoNotifier {
  _DistanciaFija(int? metros) {
    state = metros;
  }
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
    String? validate({
      double? routeDistanceMeters,
      bool ghost = false,
      int radio = 1000,
    }) =>
        validateAlertActivation(
          hasPosition: true,
          bus: _bus(ghost: ghost),
          busDistanceMeters: null,
          activeAlertsCount: 0,
          routeDistanceMeters: routeDistanceMeters,
          radioCercaM: radio,
          radioRutaM: radio,
        );

    test('rechaza el aviso si el recorrido no entra en el radio de disparo',
        () {
      expect(validate(routeDistanceMeters: 3400),
          contains('Esta ruta no pasa cerca de ti'));
      expect(validate(routeDistanceMeters: 3400), contains('3,4 km'));
    });

    // El bug que reportó el usuario: el recorrido rozaba el anillo verde de
    // 2 km y la app dejaba armar el aviso, pero el aviso solo sonaba a 1 km.
    // El botón decía «AVISO ACTIVADO» y no iba a sonar nunca.
    test('con el aviso a 1 km, una ruta entre 1 y 2 km no se arma', () {
      expect(validate(routeDistanceMeters: 1500),
          contains('Esta ruta no pasa cerca de ti'));
      expect(validate(routeDistanceMeters: 1900), isNotNull);
      expect(validate(routeDistanceMeters: 2100), isNotNull);
    });

    // La distancia la elige la persona (dueño, 2026-10-06): el tope de la
    // ruta es esa distancia, no el kilómetro de antes.
    test('el tope de la ruta es exactamente la distancia elegida', () {
      expect(validate(routeDistanceMeters: 1800, radio: 1800), isNull);
      expect(validate(routeDistanceMeters: 1801, radio: 1800), isNotNull);
      expect(validate(routeDistanceMeters: 1500, radio: 2000), isNull);
      expect(validate(routeDistanceMeters: 600, radio: 500), isNotNull);
    });

    test('dice a cuánto suena el aviso y que una distancia mayor lo arregla',
        () {
      final message = validate(routeDistanceMeters: 2400, radio: 2000)!;
      expect(message, contains('2,4 km'));
      expect(message, contains('tu aviso suena a 2,0 km'));
      expect(message, contains('Elige una distancia mayor'));
      expect(validate(routeDistanceMeters: 800, radio: 500),
          contains('tu aviso suena a 500 m'));
    });

    test('a 3 km no hay distancia mayor que ofrecer', () {
      final message = validate(routeDistanceMeters: 3400, radio: 3000)!;
      expect(message, contains('el aviso suena a 3 km como mucho'));
      expect(message, isNot(contains('distancia mayor')));
    });

    test('a 10 km o más el decimal sobra', () {
      expect(validate(routeDistanceMeters: 12400), contains('12 km'));
    });

    test('justo en el límite todavía deja armar', () {
      // 1000 m es alcanzable: el disparo es `distancia <= radio`.
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
          busDistanceMeters: null,
          activeAlertsCount: 0,
          routeDistanceMeters: 8000,
          radioCercaM: 1000,
          radioRutaM: 1000,
        ),
        contains('dónde estás'),
      );
    });
  });

  group('validateAlertActivation: bus que ya está cerca', () {
    String? validate(double? busDistanceMeters, {required int radio}) =>
        validateAlertActivation(
          hasPosition: true,
          bus: _bus(),
          busDistanceMeters: busDistanceMeters,
          activeAlertsCount: 0,
          radioCercaM: radio,
          radioRutaM: radio,
        );

    // «Ya está cerca» se mide con la misma vara que el aviso: dentro de la
    // distancia elegida el aviso sonaría ya mismo.
    test('dentro de la distancia elegida no se arma, y lo dice', () {
      expect(validate(800, radio: 800), contains('ya está a menos de 800 m'));
      expect(
          validate(1900, radio: 2500), contains('ya está a menos de 2,5 km'));
    });

    test('fuera de la distancia elegida sí se arma', () {
      expect(validate(801, radio: 800), isNull);
      expect(validate(1900, radio: 1500), isNull);
    });

    test('sin saber dónde va el bus no se rechaza', () {
      expect(validate(null, radio: 3000), isNull);
    });
  });

  group('routeDistanceToUserProvider', () {
    ProviderContainer containerWith({
      required List<GeoPoint> points,
      bool located = true,
      int? guardada = 1000,
    }) {
      final container = ProviderContainer(overrides: [
        userLocationProvider.overrideWith((ref) => _TestUserLocation()),
        distanciaAvisoProvider.overrideWith((ref) => _DistanciaFija(guardada)),
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

    test('con la distancia guardada, lejos es más allá de esa distancia', () {
      expect(
          containerWith(points: _routeAtKm(1.5), guardada: 2000)
              .read(routeTooFarFromUserProvider('R1')),
          isFalse);
      expect(
          containerWith(points: _routeAtKm(0.8), guardada: 500)
              .read(routeTooFarFromUserProvider('R1')),
          isTrue);
    });

    // Sin distancia guardada todavía se puede elegir hasta 3 km: solo es
    // lejos lo que ni a 3 km sonaría.
    test('sin distancia guardada, lejos es más allá de 3 km', () {
      expect(
          containerWith(points: _routeAtKm(2.8), guardada: null)
              .read(routeTooFarFromUserProvider('R1')),
          isFalse);
      expect(
          containerWith(points: _routeAtKm(3.2), guardada: null)
              .read(routeTooFarFromUserProvider('R1')),
          isTrue);
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
