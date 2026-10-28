// Las dos apps pintan Voyager retocado como Yandex y sin negocios (dueño,
// 2026-10-28): los nombres de sitios se confundían con los buses.
import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_core/core/theme/estilo_retocado.dart';

Map<String, dynamic> _capa(String id, [Map<String, dynamic>? paint]) => {
      'id': id,
      'type': 'line',
      'paint': {...?paint},
    };

Map<String, dynamic> _voyager() => {
      'version': 8,
      'id': 'voyager',
      'sources': {'protomaps': <String, dynamic>{}},
      'layers': [
        {
          'id': 'background',
          'type': 'background',
          'paint': {'background-color': '#fbf8f3'},
        },
        _capa('road_minor_case', {'line-color': '#ebe7e1', 'line-width': 1}),
        _capa('road_minor_fill', {'line-color': '#fff', 'line-opacity': 1}),
        _capa('road_trunk_fill_noramp', {'line-color': '#ffe9a6'}),
        _capa('poi_stadium'),
        _capa('poi_park'),
        _capa('watername_lake_pois'),
        {
          'id': 'place_suburbs',
          'type': 'symbol',
          'layout': {'text-size': 12},
          'paint': {'text-color': '#000'},
        },
      ],
    };

Map<String, dynamic> _por(Map<String, dynamic> estilo, String id) =>
    (estilo['layers'] as List).cast<Map<String, dynamic>>().firstWhere(
          (capa) => capa['id'] == id,
        );

void main() {
  test('sin nombres de sitios ni negocios', () {
    final ids = (estiloRetocado(_voyager())['layers'] as List).map(
      (capa) => (capa as Map)['id'],
    );
    expect(ids, isNot(contains(startsWith('poi_'))));
    expect(ids, isNot(contains('watername_lake_pois')));
    expect(ids, contains('road_minor_fill'));
  });

  test('papel claro, calles gris azulado con filo y avenidas aparte', () {
    final panel = estiloRetocado(_voyager());
    expect(
      _por(panel, 'background')['paint']['background-color'],
      fondoMapaHex,
    );
    final fill = _por(panel, 'road_minor_fill')['paint'] as Map;
    expect(fill['line-color'], '#D9DCE4');
    // Lo que no se retoca se queda como en Voyager.
    expect(fill['line-opacity'], 1);
    expect(_por(panel, 'road_minor_case')['paint']['line-color'], '#BCC1CC');
    expect(
      _por(panel, 'road_trunk_fill_noramp')['paint']['line-color'],
      '#CED2DB',
    );
  });

  test('los barrios en mayúsculas espaciadas y gris', () {
    final barrio = _por(estiloRetocado(_voyager()), 'place_suburbs');
    expect(barrio['layout']['text-transform'], 'uppercase');
    expect(barrio['layout']['text-size'], 12);
    expect(barrio['paint']['text-color'], '#A29B92');
  });

  // El panel guarda en disco las teselas ya pintadas con la llave
  // `id-vversión` del estilo: con la de Voyager salían las de antes del
  // retoque y el mapa nuevo no se veía.
  test('se llama distinto de Voyager, con la versión del retoque', () {
    final estilo = estiloRetocado(_voyager());
    expect(estilo['id'], isNot('voyager'));
    expect(estilo['id'], startsWith('voyager'));
    expect(estilo['metadata']['version'], versionRetoque);
  });

  test('no toca el estilo que recibe', () {
    final voyager = _voyager();
    estiloRetocado(voyager);
    expect(voyager, _voyager());
  });
}
