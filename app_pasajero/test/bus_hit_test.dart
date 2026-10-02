import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_pasajero/features/map/presentation/utils/bus_hit_test.dart';

void main() {
  test('elige el bus más cercano, no el primero de MapLibre', () {
    final selected = nearestBusId(
      const Offset(200, 200),
      const [
        BusScreenPoint(busId: 'lejos', offset: Offset(220, 200)),
        BusScreenPoint(busId: 'cerca', offset: Offset(202, 201)),
      ],
    );

    expect(selected, 'cerca');
  });

  test('no selecciona un bus fuera del radio de toque', () {
    final selected = nearestBusId(
      const Offset(200, 200),
      const [
        BusScreenPoint(busId: 'bus', offset: Offset(240, 200)),
      ],
      maxDistance: 32,
    );

    expect(selected, isNull);
  });

  // En Android el mapa nativo habla en píxeles físicos y en iOS en puntos
  // (lógicos). El radio de toque de 32 se pensó en puntos: medido en
  // píxeles de un teléfono de densidad 3 quedaba en unos 11 puntos, y
  // acertarle a un bus en Android era difícil (dueño, 2026-10-02).
  group('escala del mapa nativo', () {
    test('Android divide por la densidad; iOS ya viene en puntos', () {
      expect(escalaDelMapa(TargetPlatform.android, 2.75), 2.75);
      expect(escalaDelMapa(TargetPlatform.iOS, 3), 1);
    });

    test('un toque a 30 puntos de un bus lo elige en un Android de densidad 3',
        () {
      const escala = 3.0;
      final selected = nearestBusId(
        aPuntoLogico(const math.Point(300.0, 300.0), escala),
        [
          BusScreenPoint(
            busId: 'bus',
            offset: aPuntoLogico(const math.Point(390.0, 300.0), escala),
          ),
        ],
        maxDistance: 32,
      );
      expect(selected, 'bus');
    });

    test('el mapa no usa una coordenada nativa sin pasarla a puntos', () {
      final fuente = File(
        'lib/features/map/presentation/widgets/map_widget.dart',
      ).readAsStringSync();
      // Solo la consulta de features habla en unidades nativas, y su
      // rectángulo crece con la misma escala.
      expect(fuente, isNot(contains('.x.toDouble()')));
      expect(fuente, isNot(contains('nearestBusId(Offset(')));
      expect(fuente, contains('maxHitRadius * 2 * escala'));
    });
  });
}
