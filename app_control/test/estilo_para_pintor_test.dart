// El pintor del panel (vector_tile_renderer 6.1) no entiende los filtros
// que Voyager trae ahora: `in` con `literal` y `["zoom"]` sueltos. Las capas
// con esos filtros se pintaban vacías, y las calles chicas nunca salían
// (dueño, 2026-10-28, «no veo ningún mapa nuevo»).
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_tile_renderer/vector_tile_renderer.dart';
import 'package:ya_viene_control/features/fleet/presentation/widgets/estilo_para_pintor.dart';

class _Avisos implements Logger {
  final avisos = <String>[];

  @override
  void log(MessageFunction message) {}

  @override
  void warn(MessageFunction message) => avisos.add(message());
}

Map<String, dynamic> _estilo(List<Object> filtro) => {
  'version': 8,
  'sources': {
    'carto': {'type': 'vector'},
  },
  'layers': [
    {
      'id': 'road_minor_fill',
      'type': 'line',
      'source': 'carto',
      'source-layer': 'roads',
      'filter': filtro,
      'paint': {'line-color': '#D9DCE4'},
    },
  ],
};

const _calles = [
  'all',
  [
    '!',
    [
      'in',
      ['get', 'kind'],
      [
        'literal',
        ['path', 'highway', 'major_road'],
      ],
    ],
  ],
  [
    'in',
    ['get', 'kind_detail'],
    [
      'literal',
      ['residential', 'unclassified'],
    ],
  ],
  [
    '>=',
    ['zoom'],
    13,
  ],
];

void main() {
  test('sin traducir, el pintor no entiende el filtro', () {
    final avisos = _Avisos();
    ThemeReader(logger: avisos).read(_estilo(_calles));
    expect(avisos.avisos, isNotEmpty);
  });

  test('traducido, lo entiende entero', () {
    final avisos = _Avisos();
    ThemeReader(logger: avisos).read(estiloParaPintor(_estilo(_calles)));
    expect(avisos.avisos, isEmpty);
  });

  test('`in` con `literal` pasa a la forma vieja y `zoom` a una propiedad', () {
    final capa = (estiloParaPintor(_estilo(_calles))['layers'] as List).single;
    expect(capa['filter'], [
      'all',
      [
        '!',
        ['in', 'kind', 'path', 'highway', 'major_road'],
      ],
      ['in', 'kind_detail', 'residential', 'unclassified'],
      [
        '>=',
        ['get', 'zoom'],
        13,
      ],
    ]);
  });

  test('no toca el estilo que recibe', () {
    final estilo = _estilo(_calles);
    estiloParaPintor(estilo);
    expect(estilo, _estilo(_calles));
  });
}
