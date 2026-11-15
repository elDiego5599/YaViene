import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_core/core/lugares/buscador_local.dart';
import 'package:ya_viene_core/core/lugares/lugar.dart';
import 'package:ya_viene_core/core/models/route_trajectory.dart';

import 'indice_de_prueba.dart';

/// Metros entre dos puntos, en plano: basta a escala de ciudad.
double _metros(GeoPoint a, GeoPoint b) {
  const r = 6371000.0;
  final lat = (a.lat + b.lat) / 2 * math.pi / 180;
  final dx = (b.lon - a.lon) * math.pi / 180 * r * math.cos(lat);
  final dy = (b.lat - a.lat) * math.pi / 180 * r;
  return math.sqrt(dx * dx + dy * dy);
}

void main() {
  final buscador = BuscadorLocal.desdeJson([osmDePrueba(), potDePrueba()]);

  Future<List<String>> nombres(String q, {GeoPoint? sesgo}) async =>
      [for (final s in await buscador.buscar(q, sesgo: sesgo)) s.nombre];

  test('una consulta vacía o de puros signos no busca nada', () async {
    expect(await buscador.buscar(''), isEmpty);
    expect(await buscador.buscar('   ,  '), isEmpty);
  });

  test('encuentra un barrio sin tildes, en mayúsculas y con una letra mal',
      () async {
    expect((await nombres('santa monica')).first, 'Santa Mónica');
    expect((await nombres('SANTA MONICA')).first, 'Santa Mónica');
    expect((await nombres('la campina')).first, 'La Campiña');
    expect((await nombres('santa mnoica')).first, 'Santa Mónica');
    expect((await nombres('santa monca')).first, 'Santa Mónica');
  });

  test('lo que se va escribiendo ya encuentra: la última palabra es prefijo',
      () async {
    expect(await nombres('barrio aba'), contains('Barrio Abajo'));
    expect(await nombres('unive'), contains('Universidad del Norte'));
  });

  test('busca también por el otro nombre, y dice el de verdad', () async {
    final uninorte = await buscador.buscar('uninorte');
    expect(uninorte.first.nombre, 'Universidad del Norte');
    expect(uninorte.first.tipo, TipoLugar.sitio);
    expect(uninorte.first.contexto, 'Universidad, Puerto Colombia');
    expect((await nombres('olaya herrera')).first, 'Cra 46');
  });

  test('cada fila dice qué es y dónde', () async {
    final prado = (await buscador.buscar('el prado')).first;
    expect(prado.tipo, TipoLugar.barrio);
    expect(prado.contexto, 'Barrio, Barranquilla');
    expect(prado.lugar.origen, OrigenLugar.sitio);
    expect(prado.lugar.punto, const GeoPoint(lat: 11.0, lon: -74.8));

    final carrera = (await buscador.buscar('carrera 47')).first;
    expect(carrera.tipo, TipoLugar.via);
    expect(carrera.contexto, 'Carrera, Barranquilla');
  });

  test('los barrios del POT que OSM no trae también salen', () async {
    final boyaca = (await buscador.buscar('boyaca')).first;
    expect(boyaca.nombre, 'Boyaca');
    expect(boyaca.contexto, 'Barrio, Barranquilla');
  });

  test('entiende las abreviaturas de la nomenclatura', () async {
    for (final q in ['Cra 46', 'kr 46', 'CR 46', 'carrera 46']) {
      expect((await nombres(q)).first, 'Cra 46', reason: q);
    }
    for (final q in ['Cl 72', 'cll 72', 'Clle 72', 'calle 72']) {
      expect((await nombres(q)).first, 'Clle 72', reason: q);
    }
  });

  test('un número no se corrige: la 46 no es la 47', () async {
    expect(await nombres('carrera 48'), isEmpty);
  });

  test('lo exacto va antes que lo casi igual', () async {
    // «prado» es palabra exacta en El Prado y Portal del Prado; «Prado Mar»
    // también la trae, pero la consulta entera es «el prado».
    expect((await nombres('el prado')).first, 'El Prado');
  });

  test('entre los igual de buenos, primero el más cerca del sesgo', () async {
    const enSoledad = GeoPoint(lat: 10.91, lon: -74.77);
    const enBarranquilla = GeoPoint(lat: 10.96, lon: -74.79);
    final desdeSoledad = await buscador.buscar('calle 30', sesgo: enSoledad);
    expect(desdeSoledad.map((s) => s.contexto), [
      'Calle, Soledad',
      'Calle, Barranquilla',
    ]);
    final desdeBq = await buscador.buscar('calle 30', sesgo: enBarranquilla);
    expect(desdeBq.first.contexto, 'Calle, Barranquilla');
  });

  test('una vía cae en su punto más cerca del sesgo', () async {
    const sesgo = GeoPoint(lat: 11.0050, lon: -74.8150);
    final calle72 = (await buscador.buscar('calle 72', sesgo: sesgo)).first;
    expect(
        _metros(calle72.lugar.punto, const GeoPoint(lat: 11.0, lon: -74.815)),
        lessThan(2));
  });

  test('sin sesgo, una vía cae en su mitad', () async {
    final calle72 = (await buscador.buscar('calle 72')).first;
    expect(
        _metros(calle72.lugar.punto, const GeoPoint(lat: 11.0, lon: -74.805)),
        lessThan(2));
  });

  group('direcciones', () {
    const esquina = GeoPoint(lat: 11.0, lon: -74.805);

    test('«Calle 72 con 46» es la esquina', () async {
      for (final q in [
        'Calle 72 con 46',
        'cl 72 con cra 46',
        'calle 72 con carrera 46',
        'Calle 72 #46',
        'Clle 72 con Cra 46',
        'calle 72 y 46',
      ]) {
        final s = await buscador.buscar(q);
        expect(s, isNotEmpty, reason: q);
        expect(s.first.tipo, TipoLugar.cruce, reason: q);
        expect(_metros(s.first.lugar.punto, esquina), lessThan(2), reason: q);
      }
    });

    // Como se escriben aquí (dueño, 2026-11-15): «Clle 72 con Cra 46».
    test('la esquina se nombra entera, a la manera de aquí, y dice dónde',
        () async {
      final s = (await buscador.buscar('cl 72 con 46')).first;
      expect(s.nombre, 'Clle 72 con Cra 46');
      expect(s.contexto, 'Esquina, Barranquilla');
    });

    test('al revés también: «Carrera 46 con 72»', () async {
      final s = (await buscador.buscar('Carrera 46 con 72')).first;
      expect(s.nombre, 'Cra 46 con Clle 72');
      expect(_metros(s.lugar.punto, esquina), lessThan(2));
    });

    test('«Calle 72 # 46-20» camina 20 m desde la esquina hacia la 47',
        () async {
      for (final q in [
        'Calle 72 # 46-20',
        'cl 72 No. 46 - 20',
        'cl72#46-20',
        'Clle 72 #46-20',
      ]) {
        final s = await buscador.buscar(q);
        expect(s.first.tipo, TipoLugar.cruce, reason: q);
        expect(s.first.nombre, 'Clle 72 #46-20', reason: q);
        final p = s.first.lugar.punto;
        expect(_metros(p, esquina), closeTo(20, 2), reason: q);
        // Hacia la 47, que está al oeste.
        expect(p.lon, lessThan(esquina.lon), reason: q);
        expect(p.lat, closeTo(11.0, 1e-5), reason: q);
        expect(s.first.contexto, 'Dirección, Barranquilla', reason: q);
      }
    });

    test('mientras se escribe el número de la otra vía ya salen esquinas',
        () async {
      final s = await buscador.buscar('calle 72 con 4');
      expect(
        s.where((x) => x.tipo == TipoLugar.cruce).map((x) => x.nombre),
        ['Clle 72 con Cra 46', 'Clle 72 con Cra 47'],
      );
    });

    test('con la vía y el conector, sin la otra todavía, sale la vía',
        () async {
      expect((await nombres('calle 72 con')).first, 'Clle 72');
    });

    test('dos vías que no se cruzan no inventan una esquina', () async {
      final s = await buscador.buscar('calle 72 con 50');
      expect(s.where((x) => x.tipo == TipoLugar.cruce), isEmpty);
    });

    test('vías de municipios distintos no se cruzan', () async {
      final s = await buscador.buscar('calle 30 con 46');
      expect(s.where((x) => x.tipo == TipoLugar.cruce), isEmpty);
    });
  });

  test('respeta el máximo', () async {
    final s = await buscador.buscar('a', maximo: 2);
    expect(s.length, lessThanOrEqualTo(2));
  });

  test('dice de dónde salen los datos', () {
    expect(buscador.atribucion, contains('OpenStreetMap'));
    expect(buscador.atribucion, contains('Alcaldía'));
  });
}
