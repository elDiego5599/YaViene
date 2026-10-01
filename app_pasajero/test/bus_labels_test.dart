import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_pasajero/core/utils/bus_labels.dart';

void main() {
  test('la placa de un bus real sale del id BUS-<placa>', () {
    expect(busPlaca('BUS-SQA101'), 'SQA101');
    expect(busPlaca('BUS-ABC123'), 'ABC123');
    expect(busPlaca('BUS-sqa223'), 'SQA223');
    expect(busPlaca('  BUS-SQA223  '), 'SQA223');
  });

  test('formato real de placa (3 letras 3 números): sqa223 → SQA223', () {
    // La app de control guarda placas tipo "sqa223"; el backend las
    // normaliza a mayúsculas y crea el id BUS-SQA223.
    expect(busPlaca('BUS-SQA223'), 'SQA223');
    expect(
      routePlateLabel(busId: 'BUS-SQA223', routeName: 'Calle 72 - Uninorte'),
      'Calle 72 - Uninorte - SQA223',
    );
  });

  test('la flota demo también lleva placa de verdad', () {
    expect(busPlaca('BUS-WGV705'), 'WGV705');
    expect(busPlaca('BUS-WFK042'), 'WFK042');
  });

  test('un id que no sale de una placa se enseña tal cual', () {
    expect(busPlaca('B-042'), 'B-042');
    expect(busPlaca('BUS-GPS-7'), 'GPS-7');
  });

  test('la etiqueta es nombre de ruta - placa (ruta preferida)', () {
    expect(
      routePlateLabel(
          busId: 'BUS-WGV705',
          routeName: 'Calle 72 - Uninorte',
          routeId: 'R-106'),
      'Calle 72 - Uninorte - WGV705',
    );
    expect(
      routePlateLabel(
          busId: 'BUS-SQA101',
          routeName: 'Carrera 54 - Uninorte',
          routeId: 'R-105'),
      'Carrera 54 - Uninorte - SQA101',
    );
  });

  test('sin nombre de ruta cae al id de la ruta', () {
    expect(
      routePlateLabel(busId: 'BUS-WGV705', routeId: 'R-106'),
      'R-106 - WGV705',
    );
    expect(
      routePlateLabel(busId: 'BUS-WGV705', routeName: '  ', routeId: 'R-106'),
      'R-106 - WGV705',
    );
  });

  test('sin ruta se queda solo la placa', () {
    expect(routePlateLabel(busId: 'BUS-WGV705'), 'WGV705');
  });
}
