import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_core/core/lugares/buscador_falso.dart';
import 'package:ya_viene_core/core/lugares/lugar.dart';
import 'package:ya_viene_core/core/models/route_trajectory.dart';

void main() {
  const prado = Sugerencia(
    lugar: Lugar(
      punto: GeoPoint(lat: 11.0, lon: -74.8),
      origen: OrigenLugar.sitio,
      nombre: 'El Prado',
    ),
    tipo: TipoLugar.barrio,
    contexto: 'Barrio, Barranquilla',
  );
  const portal = Sugerencia(
    lugar: Lugar(
      punto: GeoPoint(lat: 10.993, lon: -74.793),
      origen: OrigenLugar.sitio,
      nombre: 'Portal del Prado',
    ),
    tipo: TipoLugar.sitio,
    contexto: 'Centro comercial, Barranquilla',
  );

  test('responde lo que se le dio para esa consulta, hasta el máximo',
      () async {
    final falso = BuscadorFalso(respuestas: {
      'prado': [prado, portal],
    });
    expect(await falso.buscar('prado'), [prado, portal]);
    expect(await falso.buscar('prado', maximo: 1), [prado]);
    expect(await falso.buscar('otra cosa'), isEmpty);
  });

  test('anota cada consulta con su sesgo', () async {
    final falso = BuscadorFalso();
    const sesgo = GeoPoint(lat: 11.0, lon: -74.8);
    await falso.buscar('prado', sesgo: sesgo);
    expect(falso.consultas, [(consulta: 'prado', sesgo: sesgo)]);
  });

  test('con un error, cada búsqueda lo lanza', () async {
    final falso = BuscadorFalso(error: StateError('índice roto'));
    await expectLater(falso.buscar('prado'), throwsStateError);
  });

  testWidgets('tarda lo que se le pide', (tester) async {
    final falso = BuscadorFalso(
      respuestas: {
        'prado': [prado],
      },
      demora: const Duration(milliseconds: 300),
    );
    List<Sugerencia>? hallado;
    unawaited(falso.buscar('prado').then((s) => hallado = s));
    await tester.pump(const Duration(milliseconds: 299));
    expect(hallado, isNull);
    await tester.pump(const Duration(milliseconds: 1));
    expect(hallado, [prado]);
  });

  test('dice la atribución que se le dé', () {
    expect(BuscadorFalso(atribucion: '© prueba').atribucion, '© prueba');
  });
}
