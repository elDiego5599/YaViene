// El pasajero pinta el mismo mapa retocado que el panel, sin negocios
// (dueño, 2026-10-28). Si el retoque no llega, el mapa sale igual: con el
// Voyager de siempre, nunca en blanco.
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/estilo_mapa_provider.dart';

Future<String> _leer(http.Client cliente) => http.runWithClient(() {
      final contenedor = ProviderContainer();
      addTearDown(contenedor.dispose);
      return contenedor.read(estiloMapaProvider.future);
    }, () => cliente);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('baja Voyager y lo entrega retocado, sin negocios', () async {
    final pedidas = <Uri>[];
    final estilo = await _leer(
      MockClient((pedido) async {
        pedidas.add(pedido.url);
        return http.Response(
          jsonEncode({
            'version': 8,
            'layers': [
              {'id': 'background', 'type': 'background', 'paint': {}},
              {'id': 'poi_stadium', 'type': 'symbol'},
            ],
          }),
          200,
        );
      }),
    );
    expect(pedidas, [Uri.parse(kEstiloMapa)]);
    final capas = (jsonDecode(estilo)['layers'] as List).cast<Map>();
    expect(capas.map((capa) => capa['id']), ['background']);
    expect(capas.single['paint']['background-color'], fondoDelMapa);
  });

  test('sin red o con un error, el Voyager de siempre', () async {
    expect(
      await _leer(MockClient((_) async => http.Response('', 503))),
      kEstiloMapa,
    );
    expect(
      await _leer(MockClient((_) async => throw http.ClientException('x'))),
      kEstiloMapa,
    );
    expect(
      await _leer(MockClient((_) async => http.Response('<html>', 200))),
      kEstiloMapa,
    );
  });

  group('primeraCapaDeRotulos', () {
    // La ruta se mete bajo los rótulos para que «Soledad» o «BARRANQUILLA»
    // se lean encima de la línea verde (AUD29-37).
    test('da la primera capa de símbolos del estilo', () {
      final estilo = jsonEncode({
        'layers': [
          {'id': 'background', 'type': 'background'},
          {'id': 'road', 'type': 'line'},
          {'id': 'place_city', 'type': 'symbol'},
          {'id': 'road_label', 'type': 'symbol'},
        ],
      });
      expect(primeraCapaDeRotulos(estilo), 'place_city');
    });

    // Voyager pone `waterway_label` antes de calles y edificios: meter la
    // ruta bajo ese rótulo la dejaba tapada por todo el mapa.
    test('salta los rótulos que van debajo de calles y edificios', () {
      final estilo = jsonEncode({
        'layers': [
          {'id': 'water', 'type': 'fill'},
          {'id': 'waterway_label', 'type': 'symbol'},
          {'id': 'road_pri_fill', 'type': 'line'},
          {'id': 'building', 'type': 'fill'},
          {'id': 'place_suburbs', 'type': 'symbol'},
          {'id': 'roadname_pri', 'type': 'symbol'},
        ],
      });
      expect(primeraCapaDeRotulos(estilo), 'place_suburbs');
    });

    test('sin símbolos, sin capas o con la dirección de Voyager, nada', () {
      expect(
        primeraCapaDeRotulos(jsonEncode({
          'layers': [
            {'id': 'road', 'type': 'line'},
          ],
        })),
        isNull,
      );
      expect(primeraCapaDeRotulos(jsonEncode({'version': 8})), isNull);
      expect(primeraCapaDeRotulos(kEstiloMapa), isNull);
    });
  });
}
