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
}
