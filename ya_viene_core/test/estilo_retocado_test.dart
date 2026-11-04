// Las dos apps pintan Voyager retocado como Yandex y sin negocios (dueño,
// 2026-10-28): los nombres de sitios se confundían con los buses.
import 'dart:convert';

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
          'source': 'protomaps',
          'source-layer': 'landuse',
          'filter': [
            'in',
            ['get', 'kind'],
            [
              'literal',
              ['wood', 'park'],
            ],
          ],
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

  test('calles gris azulado con filo y avenidas aparte', () {
    final panel = estiloRetocado(_voyager());
    final fill = _por(panel, 'road_minor_fill')['paint'] as Map;
    expect(_deCerca(fill['line-color']), '#D9DCE4');
    // Lo que no se retoca se queda como en Voyager.
    expect(fill['line-opacity'], 1);
    expect(
      _deCerca(_por(panel, 'road_minor_case')['paint']['line-color']),
      '#BCC1CC',
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

  // En Yandex todo lo que no está construido es verde: el monte al oeste y
  // al sur, las orillas, los lotes dentro de la ciudad (dueño, 2026-11-03,
  // «hay un montón de verde en el mapa de Yandex que no tenemos»). OSM no
  // dibuja ese monte, así que se pinta al revés: el suelo es monte y la
  // ciudad se pone encima en papel.
  test('el suelo es monte y la ciudad va encima en papel', () {
    final estilo = estiloRetocado(_voyager());
    expect(
      _por(estilo, 'background')['paint']['background-color'],
      monteMapaHex,
    );
    final ids = (estilo['layers'] as List).map((capa) => (capa as Map)['id']);
    // Justo encima del suelo y debajo de todo lo demás: los parques, el
    // agua y las calles se pintan sobre el papel.
    expect(ids.take(4), [
      'background',
      'suelo_ciudad',
      'suelo_avenidas',
      'suelo_calles',
    ]);
    final ciudad = _por(estilo, 'suelo_ciudad');
    expect(ciudad['source'], 'protomaps');
    expect(ciudad['source-layer'], 'landuse');
    expect(ciudad['paint']['fill-color'], fondoMapaHex);
    expect(
      ((ciudad['filter'] as List)[2] as List)[1],
      containsAll(['residential', 'industrial', 'commercial', 'school']),
    );
    // Las manzanas sin uso marcado en OSM son papel por sus calles.
    for (final id in ['suelo_avenidas', 'suelo_calles']) {
      final calle = _por(estilo, id);
      expect(calle['source-layer'], 'roads');
      expect(calle['paint']['line-color'], fondoMapaHex);
    }
  });

  // El papel que va bajo cada calle se mide en metros, como una manzana a
  // lado y lado: con píxeles fijos, de lejos se comía el monte y de cerca
  // dejaba verde entre las casas.
  test('el papel de cada calle tiene el ancho de una manzana en metros', () {
    final estilo = estiloRetocado(_voyager());
    final ancho = _por(estilo, 'suelo_calles')['paint']['line-width'] as Map;
    expect(ancho['base'], 2);
    final [[z1, px1], [z2, px2]] = (ancho['stops'] as List).cast<List>();
    // Igual en metros: cada zoom de más dobla los píxeles.
    expect(
      (px2 as num) / (px1 as num),
      closeTo(1 << ((z2 as num) - (z1 as num)).toInt(), 0.01),
    );
    // 120 m a la latitud de Barranquilla, en teselas de 512.
    expect(px1 * 76832 / (1 << z1.toInt()), closeTo(120, 1));
  });

  // Las autopistas van por el monte: no llevan papel debajo, o pintarían
  // un camino de ciudad donde no la hay.
  test('las autopistas no llevan papel', () {
    final filtro = jsonEncode(
      _por(estiloRetocado(_voyager()), 'suelo_avenidas')['filter'],
    );
    expect(filtro, contains('major_road'));
    expect(filtro, contains('trunk'));
    expect(filtro, contains('"!"'));
  });

  // Dos verdes como en Yandex: el claro del monte y uno más vivo para los
  // parques, bosques y canchas, que se leen como manchas sobre el monte.
  test('los parques, más verdes que el monte', () {
    final estilo = estiloRetocado(_voyager());
    for (final id in ['landuse', 'landcover']) {
      final verde = _por(estilo, id)['paint']['fill-color'] as String;
      expect(verde, parqueMapaHex);
      expect(_por(estilo, id)['paint']['fill-opacity'], 1);
    }
    expect(_luz(parqueMapaHex), lessThan(_luz(monteMapaHex)));
    expect(_luz(monteMapaHex), lessThan(_luz(fondoMapaHex)));
  });

  // Voyager deja fuera del verde los humedales, los cultivos, las reservas
  // y las playas: alrededor de la Ciénaga de Mallorquín son casi todo.
  test('los humedales, cultivos y reservas también son verdes', () {
    final filtro =
        _por(estiloRetocado(_voyager()), 'landcover')['filter'] as List;
    expect(
      (filtro[2] as List)[1],
      containsAll([
        'wood',
        'park',
        'wetland',
        'farmland',
        'nature_reserve',
        'beach',
      ]),
    );
  });

  // Las avenidas, gris azulado con el centro claro, como en Yandex: con el
  // relleno gris se veían pesadas y lavadas a la vez.
  test('las avenidas llevan filo azulado y centro claro', () {
    final estilo = estiloRetocado(_voyager());
    final centro = _deCerca(
      _por(estilo, 'road_trunk_fill_noramp')['paint']['line-color'],
    );
    expect(_luz(centro), greaterThan(_luz('#D9DCE4')));
  });

  // `water_shadow` va encima de `water`, corrida unos píxeles: lo que se ve
  // del río es la sombra, y el agua queda como su orilla. El azul de Yandex
  // va en la sombra y la orilla un poco más honda.
  test('el agua en el azul de Yandex, con su orilla más honda', () {
    final panel = estiloRetocado(_voyager());
    final rio = _por(panel, 'water_shadow')['paint']['fill-color'] as String;
    final orilla = _por(panel, 'water')['paint']['fill-color'] as String;
    expect(rio, '#9FD1F6');
    expect(_luz(orilla), lessThan(_luz(rio)));
  });

  // Con el monte, los barrios caen a veces sobre verde: su gris de antes
  // daba 2,2:1 ahí (dueño, 2026-11-03, «mide el contraste»).
  test('los barrios en mayúsculas espaciadas y gris', () {
    final barrio = _por(estiloRetocado(_voyager()), 'place_suburbs');
    expect(barrio['layout']['text-transform'], 'uppercase');
    expect(barrio['layout']['text-size'], 12);
    expect(barrio['paint']['text-color'], '#878077');
  });

  // El panel guarda en disco las teselas ya pintadas con la llave
  // `id-vversión` del estilo: con la de Voyager salían las de antes del
  // retoque y el mapa nuevo no se veía.
  test('los ríos y lagos se rotulan en un azul que se lee', () {
    final estilo = estiloRetocado({
      ..._voyager(),
      'layers': [
        ...(_voyager()['layers'] as List),
        {'id': 'waterway_label', 'type': 'symbol'},
      ],
    });
    expect(_por(estilo, 'waterway_label')['paint']['text-color'], '#2A72A6');
  });

  test('se llama distinto de Voyager, con la versión del retoque', () {
    final estilo = estiloRetocado(_voyager());
    expect(estilo['id'], isNot('voyager'));
    expect(estilo['id'], startsWith('voyager'));
    expect(estilo['metadata']['version'], versionRetoque);
  });

  test('sin capa de uso del suelo no hay papel que poner', () {
    final ids = (estiloRetocado({
      'layers': [
        {'id': 'background', 'type': 'background'},
      ],
    })['layers'] as List)
        .map((capa) => (capa as Map)['id']);
    expect(ids, ['background']);
  });

  test('no toca el estilo que recibe', () {
    final voyager = _voyager();
    estiloRetocado(voyager);
    expect(voyager, _voyager());
  });
}
