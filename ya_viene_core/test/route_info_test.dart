import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

// `GET /api/companies/:id/routes` manda el identificador como `routeId`, que
// es como lo llama el resto del contrato, y también como `id` mientras
// queden apps instaladas que solo leen ese. Esta app lee `routeId` y cae a
// `id` para hablar con un backend que todavía no lo manda.
void main() {
  test('lee routeId cuando el backend lo manda', () {
    final ruta = RouteInfo.fromJson(const {
      'routeId': 'R-101',
      'id': 'R-101',
      'name': 'Ruta 101',
      'companyId': 'EMP-1',
    });
    expect(ruta.id, 'R-101');
    expect(ruta.name, 'Ruta 101');
    expect(ruta.companyId, 'EMP-1');
  });

  test('routeId manda sobre id si no coinciden', () {
    final ruta = RouteInfo.fromJson(const {'routeId': 'R-2', 'id': 'R-1'});
    expect(ruta.id, 'R-2');
  });

  test('con un backend que solo manda id, lee id', () {
    final ruta = RouteInfo.fromJson(const {'id': 'R-7', 'name': 'Ruta 7'});
    expect(ruta.id, 'R-7');
  });

  test('lo que guardó toJson se vuelve a leer igual', () {
    const ruta = RouteInfo(
      id: 'R-9',
      name: 'Ruta 9',
      companyId: 'EMP-2',
      terminalA: 'A',
      terminalB: 'B',
    );
    expect(RouteInfo.fromJson(ruta.toJson()), ruta);
  });
}
