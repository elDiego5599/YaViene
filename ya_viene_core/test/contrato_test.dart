// El contrato con el backend (T8.5), del lado del pasajero.
//
// Los archivos de test/fixtures/contrato/ no se escriben a mano: los genera
// tests/contrato.test.ts en YaVieneBackend con el servidor de verdad, y
// tool/sincronizar-contrato.sh los copia aquí. Si el backend cambia la forma
// de una respuesta, al traer el contrato nuevo estas pruebas se enteran antes
// que un teléfono.
//
// Las fechas del contrato están fijadas en 2026-01-01 para que el archivo no
// cambie en cada corrida, y `BusPosition.tryParse` rechaza con razón una
// posición en vivo de hace meses: por eso se corren a «ahora» antes de leer.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

const _carpeta = 'test/fixtures/contrato';

Object? _leer(String nombre) =>
    jsonDecode(File('$_carpeta/$nombre.json').readAsStringSync());

Map<String, dynamic> _mapa(String nombre) =>
    _leer(nombre) as Map<String, dynamic>;

/// La posición con la fecha del servidor puesta en este momento.
Map<String, dynamic> _deAhora(Object? json) => {
      ...json as Map<String, dynamic>,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
    };

/// Todas las posiciones que el pasajero lee, con de dónde salen.
Map<String, Map<String, dynamic>> _posicionesDelPasajero() => {
      'socket-pasajero-bus-position': _mapa('socket-pasajero-bus-position'),
      'socket-pasajero-bus-visible.position':
          _mapa('socket-pasajero-bus-visible')['position']
              as Map<String, dynamic>,
      for (final lote in [
        'socket-pasajero-positions-update',
        'socket-pasajero-positions-batch',
        'rest-route-positions',
      ])
        for (final (i, bus) in (_mapa(lote)['buses'] as List).indexed)
          '$lote.buses[$i]': bus as Map<String, dynamic>,
    };

/// Las claves que aparecen en [json], a cualquier profundidad.
Set<String> _claves(Object? json) => switch (json) {
      Map() => {
          for (final MapEntry(:key, :value) in json.entries) ...{
            key as String,
            ..._claves(value),
          },
        },
      List() => {for (final item in json) ..._claves(item)},
      _ => const {},
    };

void main() {
  test('el contrato trae los archivos que estas pruebas conocen', () {
    // Un evento nuevo en el backend entra aquí a propósito, con su prueba.
    // Los tres de los avisos con la app cerrada (D13 del backend) solo los
    // lee el pasajero en Android: su prueba es
    // app_pasajero/test/avisos_push_test.dart.
    final nombres = Directory(_carpeta)
        .listSync()
        .map((f) => f.uri.pathSegments.last)
        .toSet();
    expect(nombres, {
      for (final n in [
        'push-bus-cerca',
        'rest-admin-login',
        'rest-panel-renovar',
        'rest-aviso-creado',
        'rest-aviso-enviado',
        'rest-busqueda-registrada',
        'rest-companies',
        'rest-company-routes',
        'rest-fleet-bus-created',
        'rest-fleet-bus-updated',
        'rest-fleet-positions',
        'rest-fleet-routes',
        'rest-fleet-visibility-all',
        'rest-fleet-visibility',
        'rest-panel-busquedas',
        'rest-panel-busquedas-calor',
        'rest-route-positions',
        'socket-panel-bus-hidden',
        'socket-panel-bus-left',
        'socket-panel-bus-position',
        'socket-panel-bus-removed',
        'socket-panel-bus-visible-sin-posicion',
        'socket-panel-bus-visible',
        'socket-panel-fleet-batch',
        'socket-pasajero-bus-hidden',
        'socket-pasajero-bus-left',
        'socket-pasajero-bus-position',
        'socket-pasajero-bus-removed',
        'socket-pasajero-bus-visible',
        'socket-pasajero-positions-batch',
        'socket-pasajero-positions-update',
      ])
        '$n.json',
    });
  });

  test('GET /api/companies se lee como Company', () {
    final empresas = (_leer('rest-companies') as List)
        .map((e) => Company.fromJson(e as Map<String, dynamic>))
        .toList();
    expect(empresas, isNotEmpty);
    for (final empresa in empresas) {
      expect(empresa.id, isNotEmpty);
      expect(empresa.name, isNotEmpty);
    }
  });

  test('GET /api/companies/:id/routes se lee como RouteInfo', () {
    final crudas =
        (_leer('rest-company-routes') as List).cast<Map<String, dynamic>>();
    expect(crudas, isNotEmpty);
    for (final cruda in crudas) {
      final ruta = RouteInfo.fromJson(cruda);
      expect(ruta.id, cruda['routeId']);
      expect(ruta.id, isNotEmpty);
      expect(ruta.name, isNotEmpty);
      expect(ruta.companyId, isNotEmpty);
      expect(ruta.terminalA, isNotEmpty);
      expect(ruta.terminalB, isNotEmpty);
    }
  });

  test('cada posición que recibe el pasajero pasa por BusPosition.tryParse',
      () {
    final posiciones = _posicionesDelPasajero();
    expect(posiciones.length, 8);
    for (final MapEntry(key: origen, value: json) in posiciones.entries) {
      final pos = BusPosition.tryParse(_deAhora(json));
      expect(pos, isNotNull, reason: '$origen no se pudo leer');
      expect(pos!.busId, json['busId'], reason: origen);
      expect(pos.routeId, json['routeId'], reason: origen);
      expect(pos.lat, json['lat'], reason: origen);
      expect(pos.lon, json['lon'], reason: origen);
      expect(pos.heading, json['heading'], reason: origen);
      expect(pos.speedKmh, json['speedKmh'], reason: origen);
      expect(pos.sentido, json['sentido'], reason: origen);
      expect(pos.isGhostBus, json['isGhost'], reason: origen);
      expect(pos.sequence, json['sequence'], reason: origen);
      // La captura ordena las posiciones de un bus (`esMasNueva`): sin ella
      // la última en llegar ganaba siempre.
      expect(pos.capturedAt, isA<int>(), reason: origen);
      expect(pos.capturedAt, json['capturedAt'], reason: origen);
    }
  });

  test('los avisos de un bus traen busId, routeId y eventId', () {
    // El pasajero descarta el aviso sin busId y deduplica por eventId.
    for (final nombre in [
      'socket-pasajero-bus-hidden',
      'socket-pasajero-bus-left',
      'socket-pasajero-bus-removed',
      'socket-pasajero-bus-visible',
    ]) {
      final aviso = _mapa(nombre);
      for (final campo in ['busId', 'routeId', 'eventId']) {
        expect(aviso[campo], isA<String>(), reason: '$nombre.$campo');
        expect(aviso[campo] as String, isNotEmpty, reason: '$nombre.$campo');
      }
    }
  });

  test('al pasajero no le llega el teléfono ni la empresa del bus', () {
    for (final nombre in [
      for (final f in Directory(_carpeta).listSync())
        f.uri.pathSegments.last.replaceAll('.json', ''),
    ].where((n) =>
        n.startsWith('socket-pasajero-') || n.startsWith('rest-route'))) {
      final claves = _claves(_leer(nombre));
      expect(claves, isNot(contains('driverPhone')), reason: nombre);
      expect(claves, isNot(contains('companyId')), reason: nombre);
    }
  });
}
