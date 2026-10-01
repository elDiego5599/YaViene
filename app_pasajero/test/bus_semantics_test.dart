import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import 'package:ya_viene_pasajero/features/map/presentation/utils/'
    'bus_semantics.dart';

/// Lo que el rotor de acciones de VoiceOver lee sobre el mapa: es la única
/// manera de elegir un bus sin ver la pantalla, así que la etiqueta tiene
/// que decir cuál bus, a cuánto y en qué estado.
void main() {
  const userLat = 10.96;
  const userLon = -74.80;

  BusPosition bus(String id, double lat, {bool ghost = false}) => BusPosition(
        busId: id,
        routeId: 'R1',
        lat: lat,
        lon: userLon,
        heading: 0,
        speedKmh: 20,
        timestamp: DateTime.now(),
        isGhostBus: ghost,
      );

  test('cada bus trae su acción, con placa y distancia', () {
    final acciones = accionesDeBuses(
      // ~555 m al norte: un grado de latitud son 111 km.
      buses: [bus('BUS-SQA223', userLat + 0.005)],
      userLat: userLat,
      userLon: userLon,
      seleccionados: const {},
    );

    expect(acciones, hasLength(1));
    expect(acciones.single.busId, 'BUS-SQA223');
    expect(acciones.single.etiqueta, startsWith('Seguir el bus SQA223, a '));
    expect(acciones.single.etiqueta, endsWith(' m de ti'));
  });

  test('pasado el kilómetro se dice en kilómetros', () {
    final acciones = accionesDeBuses(
      buses: [bus('BUS-WGV705', userLat + 0.05)],
      userLat: userLat,
      userLon: userLon,
      seleccionados: const {},
    );

    expect(acciones.single.etiqueta, 'Seguir el bus WGV705, a 5,6 km de ti');
  });

  test('el bus ya seguido ofrece soltarlo, no seguirlo otra vez', () {
    final acciones = accionesDeBuses(
      buses: [bus('BUS-WGV705', userLat + 0.005)],
      userLat: userLat,
      userLon: userLon,
      seleccionados: const {'BUS-WGV705'},
    );

    expect(acciones.single.etiqueta, startsWith('Dejar de seguir el bus '));
  });

  test('el bus sin señal lo dice', () {
    final acciones = accionesDeBuses(
      buses: [bus('BUS-WFK042', userLat + 0.005, ghost: true)],
      userLat: userLat,
      userLon: userLon,
      seleccionados: const {},
    );

    expect(acciones.single.etiqueta, endsWith(', sin señal'));
  });

  test('sin punto de espera no se inventa distancia', () {
    final acciones = accionesDeBuses(
      buses: [bus('BUS-WGV705', userLat + 0.005)],
      userLat: null,
      userLon: null,
      seleccionados: const {},
    );

    expect(acciones.single.etiqueta, 'Seguir el bus WGV705');
  });
}
