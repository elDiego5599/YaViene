// El estilo del mapa se guarda en el teléfono (dueño, 2026-11-03, «carga muy
// lento»): bajarlo de CARTO en cada arranque dejaba el mapa esperando a la
// red antes de dibujar nada. Con la copia, el mapa sale al instante y la red
// solo la refresca para la próxima vez.
import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/estilo_guardado.dart';

String _voyager(String fondo) => jsonEncode({
      'version': 8,
      'metadata': {'fondo': fondo},
      'layers': [
        {'id': 'background', 'type': 'background', 'paint': {}},
        {'id': 'poi_stadium', 'type': 'symbol'},
      ],
    });

String? _marca(String estilo) =>
    (jsonDecode(estilo)['metadata'] as Map)['fondo'] as String?;

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  test('la primera vez lo baja, lo retoca y guarda el Voyager crudo', () async {
    final estilo = await estiloDelMapa(
      prefs: prefs,
      bajarVoyager: () async => _voyager('red'),
    );
    final capas = (jsonDecode(estilo)['layers'] as List).cast<Map>();
    expect(capas.map((capa) => capa['id']), ['background']);
    expect(_marca(estilo), 'red');
    // Se guarda el crudo, no el retocado: un retoque nuevo de la app se
    // aplica sobre la copia sin esperar a la red.
    expect(prefs.getString(claveVoyagerGuardado), _voyager('red'));
  });

  test('con copia, sale de la copia sin esperar a la red', () async {
    await prefs.setString(claveVoyagerGuardado, _voyager('copia'));
    final red = Completer<String?>();
    final estilo = await estiloDelMapa(
      prefs: prefs,
      bajarVoyager: () => red.future,
    );
    expect(_marca(estilo), 'copia');
    expect(
      (jsonDecode(estilo)['layers'] as List).single['paint']
          ['background-color'],
      fondoDelMapa,
    );

    // Lo que llega después refresca la copia para el próximo arranque.
    red.complete(_voyager('nueva'));
    await pumpEventQueue();
    expect(prefs.getString(claveVoyagerGuardado), _voyager('nueva'));
  });

  test('una respuesta dañada no pisa la copia buena', () async {
    await prefs.setString(claveVoyagerGuardado, _voyager('copia'));
    await estiloDelMapa(prefs: prefs, bajarVoyager: () async => '<html>');
    await estiloDelMapa(
      prefs: prefs,
      bajarVoyager: () async => '{"error": "cuota"}',
    );
    await estiloDelMapa(
      prefs: prefs,
      bajarVoyager: () async => throw Exception('sin red'),
    );
    await pumpEventQueue();
    expect(prefs.getString(claveVoyagerGuardado), _voyager('copia'));
  });

  test('una copia dañada se ignora y se baja de nuevo', () async {
    await prefs.setString(claveVoyagerGuardado, '{rota');
    final estilo = await estiloDelMapa(
      prefs: prefs,
      bajarVoyager: () async => _voyager('red'),
    );
    expect(_marca(estilo), 'red');
    expect(prefs.getString(claveVoyagerGuardado), _voyager('red'));
  });

  test('sin copia y sin red, la dirección de Voyager', () async {
    expect(
      await estiloDelMapa(prefs: prefs, bajarVoyager: () async => null),
      kEstiloMapa,
    );
    expect(
      await estiloDelMapa(
        prefs: prefs,
        bajarVoyager: () async => throw Exception('sin red'),
      ),
      kEstiloMapa,
    );
  });
}
