import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('decodifica el catálogo de rutas fuera del hilo de interfaz', () async {
    final datos = await decodificarRutasJson(
      '{"rutas":[{"routeId":"R1","waypoints":[]}]}',
    ) as Map<String, dynamic>;

    expect((datos['rutas'] as List).single['routeId'], 'R1');
  });

  test('el error de JSON vuelve al llamador para conservar su fallback', () {
    expect(decodificarRutasJson('{'), throwsA(anything));
  });
}
