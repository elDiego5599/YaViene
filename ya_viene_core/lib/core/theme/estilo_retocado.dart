// El mapa de las dos apps: Voyager retocado al estilo de Yandex Maps y
// sin nombres de sitios ni negocios (dueño, 2026-10-28). Se buscan buses,
// y un estadio o un parque rotulado se leía como uno más. El panel lo
// estrenó y el pasajero lo siguió el mismo día: las dos apps ven la misma
// ciudad ([kEstiloMapa]).
//
// Se parte del JSON de Voyager y se retoca capa por capa, en vez de
// escribir un estilo propio entero: las teselas, las fuentes y los filtros
// siguen siendo los de CARTO, y aquí solo vive lo que cambia.

/// El fondo del mapa, el papel claro entre manzanas: lo que se ve mientras
/// llegan las teselas tiene que ser este mismo color.
const fondoMapaHex = '#F4F2EE';

/// La versión del retoque. El panel guarda en disco las teselas ya pintadas
/// con la llave `id-vversión` del estilo: cada cambio de colores sube esta
/// versión para que no salgan las pintadas con los de antes.
const versionRetoque = '2026-10-28.3';

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
/// encima de los de Voyager, así que lo que no se nombra queda igual. Los
/// retoques se aplican en orden: el último que toca una propiedad gana.
typedef _Retoque = ({
  List<String> ids,
  Map<String, Object>? paint,
  Map<String, Object>? layout,
  double? minzoom,
});

_Retoque _r(
  List<String> ids, {
  Map<String, Object>? paint,
  Map<String, Object>? layout,
  double? minzoom,
}) =>
    (ids: ids, paint: paint, layout: layout, minzoom: minzoom);

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
  _r(['background'], paint: {'background-color': fondoMapaHex}),
  // Verde de parque más vivo que el de Voyager, como el de Yandex.
  _r(
    ['landcover', 'park_*', 'landuse'],
    paint: {
      'fill-color': {
        'stops': [
          [10, '#DCEBCB'],
          [14, '#CBE8B6'],
        ],
      },
    },
  ),
  // El río en azul claro y limpio: el Magdalena tiene que leerse de lejos.
  _r(['water'], paint: {'fill-color': '#9FD0F5'}),
  _r(['water_shadow'], paint: {'fill-color': '#C4E4FA'}),
  _r(['waterway'], paint: {'line-color': '#A2D5F8'}),
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
  // lejos son el esqueleto de la ciudad, como en Yandex.
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
      'line-color': _deLejosACerca('#A9B5CA', '#A8AFBD'),
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
    paint: {'line-color': _deLejosACerca('#A9B5CA', '#CED2DB')},
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
  // buses.
  _r(
    ['place_suburbs', 'place_hamlet'],
    layout: {
      'text-letter-spacing': 0.1,
      'text-transform': 'uppercase',
      'text-font': _montserrat,
    },
    paint: {
      'text-color': '#A29B92',
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
    paint: {'text-color': '#3E8FC4', 'text-halo-color': '#E6F3FC'},
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
  final capas = <Map<String, dynamic>>[];
  for (final original in (voyager['layers'] as List).cast<Map>()) {
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
      if (retoque.minzoom case final minzoom?) capa['minzoom'] = minzoom;
    }
    capas.add(capa);
  }
  return {
    ...voyager,
    'id': '${voyager['id'] ?? 'voyager'}-ya-viene',
    'metadata': {...?(voyager['metadata'] as Map?), 'version': versionRetoque},
    'layers': capas,
  };
}
