import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_pasajero/core/utils/bus_labels.dart';

void main() {
  test('la placa de un bus real sale del id BUS-<placa>', () {
    expect(busPlaca('BUS-SQA101'), 'SQA101');
    expect(busPlaca('BUS-ABC123'), 'ABC123');
  });

  test('formato real de placa (3 letras 3 números): sqa223 → SQA223', () {
    // La app de control guarda placas tipo "sqa223"; el backend las
    // normaliza a mayúsculas y crea el id BUS-SQA223.
    expect(busPlaca('BUS-SQA223'), 'SQA223');
    expect(
      routePlateLabel(busId: 'BUS-SQA223', routeName: 'Ruta 1'),
      'Ruta 1 · SQA223',
    );
  });

  test('los buses demo ya traen su placa/interno como id', () {
    expect(busPlaca('B-042'), 'B-042');
    expect(busPlaca('B-055'), 'B-055');
  });

  test('la etiqueta es ruta · placa (nombre de ruta preferido)', () {
    expect(
      routePlateLabel(busId: 'B-042', routeName: 'Ruta 1', routeId: 'R1'),
      'Ruta 1 · B-042',
    );
    expect(
      routePlateLabel(busId: 'BUS-SQA101', routeName: 'Ruta 1', routeId: 'R1'),
      'Ruta 1 · SQA101',
    );
  });

  test('sin nombre de ruta cae al id de la ruta', () {
    expect(routePlateLabel(busId: 'B-042', routeId: 'R1'), 'R1 · B-042');
  });

  test('sin ruta se queda solo la placa', () {
    expect(routePlateLabel(busId: 'B-042'), 'B-042');
  });
}