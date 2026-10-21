import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_pasajero/core/services/cola_eventos.dart';

void main() {
  test('retiene el toque nativo hasta que Dart instala el listener', () async {
    final eventos = ColaEventos<String>();

    eventos.agregar('yaviene://aviso?busId=B-1&routeId=R-1');

    expect(
      await eventos.stream.first,
      'yaviene://aviso?busId=B-1&routeId=R-1',
    );
  });
}
