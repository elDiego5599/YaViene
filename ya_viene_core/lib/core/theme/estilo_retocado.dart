// El mapa de las dos apps: Voyager retocado al estilo de Yandex Maps y
// sin nombres de sitios ni negocios (dueño, 2026-10-28). Se buscan buses,
// y un estadio o un parque rotulado se leía como uno más. El panel lo
// estrenó y el pasajero lo siguió el mismo día: las dos apps ven la misma
// ciudad ([kEstiloMapa]).
//
// Se parte del JSON de Voyager y se retoca capa por capa, en vez de
// escribir un estilo propio entero: las teselas, las fuentes y los filtros
// siguen siendo los de CARTO, y aquí solo vive lo que cambia.

/// El papel de la ciudad, claro entre manzanas: lo que se ve mientras llegan
/// las teselas tiene que ser este mismo color, porque las apps abren sobre
/// Barranquilla.
const fondoMapaHex = '#F4F2EE';

/// El monte: el suelo de todo lo que no está construido, en el verde claro
/// de Yandex (#D3EBB9; dueño, 2026-11-03). La ciudad se pinta encima.
const monteMapaHex = '#D6ECBF';

/// Parques, bosques, canchas y humedales: un verde más vivo que el monte,
/// para que se lean como manchas sobre él, como en Yandex.
const parqueMapaHex = '#C4E3A5';

/// Desde qué zoom el suelo es monte. Las calles menores, cuyo papel tapa las
/// manzanas sin uso marcado, solo vienen en las teselas desde zoom 12: antes,
/// con monte de suelo, barrios enteros salían verdes de lejos y de cerca eran
/// ciudad (dueño, 2026-11-03). De lejos el suelo es papel y el verde es solo
/// el de los parques, humedales y montes que las teselas dibujan.
const zoomDelMonte = 12;

/// El color del suelo: papel hasta [zoomDelMonte] y monte desde un zoom más.
const Map<String, Object> fondoDelMapa = {
  'stops': [
    [zoomDelMonte, fondoMapaHex],
    [zoomDelMonte + 1, monteMapaHex],
  ],
};

/// La versión del retoque. El panel guarda en disco las teselas ya pintadas
/// con la llave `id-vversión` del estilo: cada cambio de colores sube esta
/// versión para que no salgan las pintadas con los de antes.
const versionRetoque = '2026-11-03.3';

/// Capas que no van: los rótulos de estadios, parques y lagos (los POI de
/// Voyager) y el tinte de las zonas residenciales, que ensuciaba el papel.
const _quitar = {
  'poi_stadium',
  'poi_park',
  'watername_lake_pois',
  'landuse_residential',
};

/// Un retoque: a qué capas se aplica y qué cambia en ellas.
///
/// Cada id es exacto, `prefijo*` o `*sufijo`. `paint` y `layout` se mezclan
/// encima de los de Voyager, así que lo que no se nombra queda igual; `filter`
/// reemplaza el de la capa entero. Los retoques se aplican en orden: el
/// último que toca una propiedad gana.
typedef _Retoque = ({
  List<String> ids,
  Map<String, Object>? paint,
  Map<String, Object>? layout,
  List<Object>? filter,
  double? minzoom,
});

_Retoque _r(
  List<String> ids, {
  Map<String, Object>? paint,
  Map<String, Object>? layout,
  List<Object>? filter,
  double? minzoom,
}) =>
    (ids: ids, paint: paint, layout: layout, filter: filter, minzoom: minzoom);

/// `["in", ["get", "kind"], ["literal", kinds]]`, la forma que usa Voyager y
/// que el pintor del panel sabe leer (`estiloParaPintor`).
List<Object> _kindEn(List<String> kinds) => [
      'in',
      ['get', 'kind'],
      ['literal', kinds],
    ];

/// Lo construido, que va en papel sobre el monte. Todo uso de suelo que no
/// es verde ni agua.
const _usosDeCiudad = [
  'residential',
  'industrial',
  'commercial',
  'retail',
  'school',
  'kindergarten',
  'hospital',
  'clinic',
  'university',
  'college',
  'military',
  'naval_base',
  'aerodrome',
  'railway',
  'pedestrian',
  'place_of_worship',
  'parking',
  'garages',
  'prison',
  'construction',
  'brownfield',
  'landfill',
  'quarry',
  'platform',
  'port',
  'marina',
  'zoo',
  'theme_park',
  'fairground',
  'attraction',
  'tourism',
  'sports_centre',
  'other',
];

/// Lo verde. Voyager deja fuera humedales, cultivos, reservas y playas, que
/// alrededor de la Ciénaga de Mallorquín y del río son casi todo.
const _usosVerdes = [
  'wood',
  'forest',
  'grass',
  'park',
  'meadow',
  'scrub',
  'garden',
  'recreation_ground',
  'village_green',
  'allotments',
  'golf_course',
  'grassland',
  'heath',
  'wetland',
  'farmland',
  'orchard',
  'vineyard',
  'plant_nursery',
  'nature_reserve',
  'national_park',
  'protected_area',
  'beach',
];

/// Metros por píxel por 2^zoom a la latitud de Barranquilla (11° N), en
/// teselas de 512: 40.075.016 · cos 11° / 512.
const _metrosPorPixelZ0 = 76832.0;

/// Un ancho de línea de [metros] en el suelo, igual a todo zoom: con base 2
/// cada zoom de más dobla los píxeles, como dobla el mapa.
Map<String, Object> _anchoEnMetros(List<(int, double)> zoomYMetros) => {
      'base': 2,
      'stops': [
        for (final (zoom, metros) in zoomYMetros)
          [zoom, metros * (1 << zoom) / _metrosPorPixelZ0],
      ],
    };

/// El papel de la ciudad, que va justo encima del monte ([fuente] es la de
/// las teselas de Voyager). OSM no dibuja el monte ni marca el uso de cada
/// manzana: lo que tiene uso de ciudad es papel, y bajo cada calle va una
/// franja de papel ancha como una manzana a lado y lado, que cubre los
/// barrios sin uso marcado. Las autopistas cruzan el monte y no llevan.
List<Map<String, dynamic>> _sueloDeCiudad(String fuente) {
  Map<String, dynamic> calles(String id, List<Object> filtro, Object ancho) => {
        'id': id,
        'type': 'line',
        'source': fuente,
        'source-layer': 'roads',
        'filter': filtro,
        'layout': {'line-cap': 'round', 'line-join': 'round'},
        'paint': {'line-color': fondoMapaHex, 'line-width': ancho},
      };
  return [
    {
      'id': 'suelo_ciudad',
      'type': 'fill',
      'source': fuente,
      'source-layer': 'landuse',
      'filter': _kindEn(_usosDeCiudad),
      'paint': {'fill-color': fondoMapaHex},
    },
    // Más ancho mientras la trama de calles menores (que llega en las
    // teselas de zoom 12) aún no tapa los barrios; antes de [zoomDelMonte]
    // el suelo ya es papel y no hace falta.
    calles(
      'suelo_avenidas',
      [
        'all',
        [
          '==',
          ['get', 'kind'],
          'major_road'
        ],
        [
          '!',
          [
            'in',
            ['get', 'kind_detail'],
            [
              'literal',
              ['motorway', 'motorway_link', 'trunk', 'trunk_link'],
            ],
          ],
        ],
      ],
      _anchoEnMetros([(zoomDelMonte, 400), (13, 250), (15, 160), (18, 160)]),
    ),
    calles(
      'suelo_calles',
      [
        'all',
        [
          '==',
          ['get', 'kind'],
          'minor_road'
        ],
        [
          'in',
          ['get', 'kind_detail'],
          [
            'literal',
            [
              'residential',
              'living_street',
              'service',
              'unclassified',
              'alley'
            ],
          ],
        ],
      ],
      _anchoEnMetros([(zoomDelMonte, 120), (18, 120)]),
    ),
  ];
}

const _montserrat = [
  'Montserrat Medium',
  'Open Sans Regular',
  'Noto Sans Regular',
];

/// Un color de calle que pasa de [lejos] (hasta zoom 12,5) a [cerca] (desde
/// zoom 14).
Map<String, Object> _deLejosACerca(String lejos, String cerca) => {
      'stops': [
        [12.5, lejos],
        [14, cerca],
      ],
    };

/// El filo de las avenidas: de lejos un poco más ancho que en Voyager, para
/// que se lean como el esqueleto de la ciudad.
const Map<String, Object> _anchoAvenida = {
  'stops': [
    [8, 1],
    [11, 2.6],
    [12, 3.4],
    [13, 4.4],
    [14, 6],
    [15, 8],
    [16, 10],
    [17, 14],
    [18, 18],
  ],
};

final List<_Retoque> _retoques = [
  _r(['background'], paint: {'background-color': fondoDelMapa}),
  // Las zonas verdes sólidas y más vivas que el monte: Voyager las pinta
  // con una veladura al 40 % que en Barranquilla casi no se veía (dueño,
  // 2026-11-03, «le faltan zonas verdes»).
  _r(
    ['landcover', 'park_*', 'landuse'],
    paint: {'fill-color': parqueMapaHex, 'fill-opacity': 1},
  ),
  _r(['landcover'], filter: _kindEn(_usosVerdes)),
  // Como en Yandex, las canchas y los parques infantiles también son verdes:
  // en los barrios son casi todo el verde que hay (en el centro, 20 canchas
  // por 29 parques en una tesela de zoom 14).
  _r(
    ['landuse'],
    filter: _kindEn(['cemetery', 'stadium', 'pitch', 'playground']),
  ),
  // El río en el azul de Yandex (#9FD1F6), limpio y vivo: el Magdalena
  // tiene que leerse de lejos. `water_shadow` va encima de `water`, corrida
  // unos píxeles, así que lo que se ve es la sombra y el agua queda de
  // orilla, un poco más honda.
  _r(['water'], paint: {'fill-color': '#86C3EE'}),
  _r(['water_shadow'], paint: {'fill-color': '#9FD1F6'}),
  _r(['waterway'], paint: {'line-color': '#9FD1F6'}),
  // Calles gris azulado sobre el papel, con filo más oscuro: más oscuras
  // que las manzanas, como en Yandex (las blancas no gustaron). De lejos el
  // filo y el relleno son del mismo tono: una calle es una sola raya, y no
  // dos rayitas con un hilo claro en medio, que de lejos se veían como
  // vías de tren (dueño, 2026-10-28). De cerca se separan en filo y calle.
  _r(
    ['*_case', '*_case_noramp', '*_case_ramp'],
    paint: {'line-color': _deLejosACerca('#C9CED8', '#BCC1CC')},
  ),
  _r(
    ['*_fill', '*_fill_noramp', '*_fill_ramp'],
    paint: {'line-color': _deLejosACerca('#C9CED8', '#D9DCE4')},
  ),
  // Las avenidas y autopistas, más azules y más anchas que las calles: de
  // lejos son el esqueleto de la ciudad, como en Yandex. De cerca, filo gris
  // azulado y centro claro: con el centro gris se veían pesadas y lavadas a
  // la vez (dueño, 2026-11-03).
  _r(
    [
      'road_pri_case*',
      'road_trunk_case*',
      'road_mot_case*',
      'bridge_pri_case',
      'bridge_trunk_case',
      'bridge_mot_case',
    ],
    paint: {
      'line-color': _deLejosACerca('#9EACC4', '#9AA7BD'),
      'line-width': _anchoAvenida,
    },
  ),
  _r(
    [
      'road_pri_fill*',
      'road_trunk_fill*',
      'road_mot_fill*',
      'bridge_pri_fill',
      'bridge_trunk_fill',
      'bridge_mot_fill',
    ],
    paint: {'line-color': _deLejosACerca('#9EACC4', '#E4E8EF')},
  ),
  // Las calles de barrio salen desde zoom 11,5, finas y claras: en Yandex
  // la cuadrícula se ve entera de lejos y le da trama a la ciudad, en vez
  // de manchas de papel vacío entre avenidas.
  _r(
    ['road_minor_case', 'bridge_minor_case'],
    minzoom: 11.5,
    paint: {
      'line-color': _deLejosACerca('#CDD1DA', '#BCC1CC'),
      'line-width': {
        'stops': [
          [11.5, 0.5],
          [13, 1.2],
          [14, 2.6],
          [15, 4.4],
          [16, 6.6],
          [17, 11],
          [18, 15],
        ],
      },
    },
  ),
  _r(
    ['road_minor_fill', 'bridge_minor_fill'],
    minzoom: 13.5,
    paint: {
      'line-width': {
        'stops': [
          [13.5, 0.6],
          [14, 1.6],
          [15, 3],
          [16, 5],
          [17, 9],
          [18, 13],
        ],
      },
    },
  ),
  // Las manzanas llenas de casas con su borde, desde zoom 15.
  _r(
    ['building'],
    paint: {
      'fill-color': '#E3DED6',
      'fill-opacity': {
        'stops': [
          [14.5, 0],
          [15.5, 1],
        ],
      },
    },
  ),
  _r(
    ['building-top'],
    paint: {
      'fill-color': '#EAE6DF',
      'fill-outline-color': '#D0CAC1',
      'fill-opacity': {
        'stops': [
          [14.5, 0],
          [15.5, 1],
        ],
      },
    },
  ),
  _r(['rail', 'tunnel_rail'], paint: {'line-color': '#D2CCC3'}),
  // Barrios en mayúsculas espaciadas y gris: se leen sin pelear con los
  // buses. 3,5:1 sobre su halo de papel y 3,1:1 sobre el monte.
  _r(
    ['place_suburbs', 'place_hamlet'],
    layout: {
      'text-letter-spacing': 0.1,
      'text-transform': 'uppercase',
      'text-font': _montserrat,
    },
    paint: {
      'text-color': '#878077',
      'text-halo-color': fondoMapaHex,
      'text-halo-width': 1.5,
    },
  ),
  _r(
    ['place_villages', 'place_town', 'place_city_r6', 'place_city_r5'],
    paint: {
      'text-color': '#4A4640',
      'text-halo-color': fondoMapaHex,
      'text-halo-width': 1.5,
    },
  ),
  // Los nombres de las calles, a lo largo de cada una, en mayúsculas.
  _r(
    ['roadname_*'],
    layout: {
      'text-transform': 'uppercase',
      'text-letter-spacing': 0.06,
      'text-font': _montserrat,
    },
    paint: {
      'text-color': '#6F6B66',
      'text-halo-color': '#D9DCE4',
      'text-halo-width': 1.5,
    },
  ),
  _r(['roadname_minor'], minzoom: 15),
  _r(
    ['roadname_minor', 'roadname_sec'],
    layout: {
      'text-size': {
        'stops': [
          [15, 8.5],
          [16, 9.5],
          [18, 11],
        ],
      },
    },
  ),
  _r(
    ['waterway_label', 'watername_*'],
    // 4,6:1 sobre su halo, que es lo que rodea cada letra.
    paint: {'text-color': '#2A72A6', 'text-halo-color': '#E6F3FC'},
  ),
];

bool _toca(String patron, String id) {
  if (patron.endsWith('*')) {
    return id.startsWith(patron.substring(0, patron.length - 1));
  }
  if (patron.startsWith('*')) return id.endsWith(patron.substring(1));
  return id == patron;
}

/// El estilo de Ya Viene a partir del de Voyager. No toca [voyager]: devuelve
/// una copia con sus capas retocadas y sin las que no van.
Map<String, dynamic> estiloRetocado(Map<String, dynamic> voyager) {
  final originales = (voyager['layers'] as List).cast<Map>();
  // El papel sale de la misma fuente de la que Voyager lee el uso del
  // suelo. Un estilo sin esa capa no tiene manzanas que pintar.
  final fuente = originales
      .where((capa) => capa['source-layer'] == 'landuse')
      .map((capa) => capa['source'])
      .whereType<String>()
      .firstOrNull;
  final capas = <Map<String, dynamic>>[];
  for (final original in originales) {
    final id = original['id'] as String;
    if (_quitar.contains(id)) continue;
    final capa = Map<String, dynamic>.of(original.cast<String, dynamic>());
    for (final retoque in _retoques) {
      if (!retoque.ids.any((patron) => _toca(patron, id))) continue;
      if (retoque.paint case final paint?) {
        capa['paint'] = {...?(capa['paint'] as Map?), ...paint};
      }
      if (retoque.layout case final layout?) {
        capa['layout'] = {...?(capa['layout'] as Map?), ...layout};
      }
      if (retoque.filter case final filter?) capa['filter'] = filter;
      if (retoque.minzoom case final minzoom?) capa['minzoom'] = minzoom;
    }
    capas.add(capa);
    if (id == 'background' && fuente != null) {
      capas.addAll(_sueloDeCiudad(fuente));
    }
  }
  return {
    ...voyager,
    'id': '${voyager['id'] ?? 'voyager'}-ya-viene',
    'metadata': {...?(voyager['metadata'] as Map?), 'version': versionRetoque},
    'layers': capas,
  };
}
