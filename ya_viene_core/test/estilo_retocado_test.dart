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
        {
          'id': 'landuse',
          'type': 'fill',
          'source-layer': 'landuse',
          'filter': [
            'in',
            ['get', 'kind'],
            [
              'literal',
              ['cemetery', 'stadium'],
            ],
          ],
          'paint': {'fill-color': 'rgba(197, 225, 178, 0.4)'},
        },
        {
          'id': 'landcover',
          'type': 'fill',
          'paint': {'fill-color': 'rgba(197, 225, 178, 0.4)'},
        },
        {
          'id': 'water',
          'type': 'fill',
          'paint': {'fill-color': '#b0d0d6'},
        },
        {
          'id': 'water_shadow',
          'type': 'fill',
          'paint': {'fill-color': 'rgba(203, 225, 228, 1)'},
        },
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

/// El color de un tramo `{'stops': [[zoom, color], ...]}` al zoom más alto.
String _deCerca(Object? color) => ((color as Map)['stops'] as List).last[1];

/// El color de un tramo al zoom más bajo.
String _deLejos(Object? color) => ((color as Map)['stops'] as List).first[1];

/// La suma de los canales de un `#RRGGBB`: menos es más oscuro.
int _luz(String hex) => [1, 3, 5]
    .map((i) => int.parse(hex.substring(i, i + 2), radix: 16))
    .reduce((a, b) => a + b);

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
    expect(_deCerca(fill['line-color']), '#D9DCE4');
    // Lo que no se retoca se queda como en Voyager.
    expect(fill['line-opacity'], 1);
    expect(
      _deCerca(_por(panel, 'road_minor_case')['paint']['line-color']),
      '#BCC1CC',
    );
    expect(
      _deCerca(_por(panel, 'road_trunk_fill_noramp')['paint']['line-color']),
      '#CED2DB',
    );
  });

  // De lejos el filo y el relleno de dos tonos se veían como vías de tren
  // (dueño, 2026-10-28, «el mapa de lejos se ve horrible»): hasta zoom 12,5
  // cada calle es una sola línea, las avenidas más oscuras que el resto, y
  // la trama de calles menores sale desde 11,5, como en Yandex.
  test('de lejos cada calle es una sola línea y las avenidas mandan', () {
    final panel = estiloRetocado(_voyager());
    String deLejos(String id) =>
        _deLejos(_por(panel, id)['paint']['line-color']);
    expect(
        deLejos('road_minor_case'), isNot(deLejos('road_trunk_fill_noramp')));
    expect(_por(panel, 'road_minor_case')['minzoom'], 11.5);
    expect(_por(panel, 'road_minor_fill')['minzoom'], greaterThan(13));
    expect(
      _luz(deLejos('road_trunk_fill_noramp')),
      lessThan(_luz(deLejos('road_minor_case'))),
    );
  });

  // El verde de Voyager era una veladura al 40 % y solo cubría parques y
  // bosques: en Barranquilla casi no se veía (dueño, 2026-11-03, «le faltan
  // zonas verdes»). Como en Yandex, las canchas y los parques infantiles
  // también son verdes, y el verde es sólido.
  test('las canchas y los parques infantiles también son zona verde', () {
    final landuse = _por(estiloRetocado(_voyager()), 'landuse');
    final filtro = landuse['filter'] as List;
    expect(filtro.take(2), [
      'in',
      ['get', 'kind'],
    ]);
    expect(
      (filtro[2] as List)[1],
      containsAll(['cemetery', 'stadium', 'pitch', 'playground']),
    );
  });

  test('el verde es sólido, más vivo de cerca que de lejos', () {
    final panel = estiloRetocado(_voyager());
    for (final id in ['landuse', 'landcover']) {
      final verde = _por(panel, id)['paint']['fill-color'];
      expect(_deCerca(verde), '#C6E5AE');
      expect(_luz(_deCerca(verde)), lessThan(_luz(_deLejos(verde))));
    }
  });

  // `water_shadow` va encima de `water`, corrida unos píxeles: lo que se ve
  // del río es la sombra, y el agua queda como su orilla. El azul de Yandex
  // va en la sombra y la orilla un poco más honda.
  test('el agua en el azul de Yandex, con su orilla más honda', () {
    final panel = estiloRetocado(_voyager());
    final rio = _por(panel, 'water_shadow')['paint']['fill-color'] as String;
    final orilla = _por(panel, 'water')['paint']['fill-color'] as String;
    expect(rio, '#A4D2F4');
    expect(_luz(orilla), lessThan(_luz(rio)));
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
