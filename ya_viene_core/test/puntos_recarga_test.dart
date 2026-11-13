import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

/// Un archivo de puntos de recarga con [puntos] y la fuente `sibus`.
String archivo(List<Map<String, Object?>> puntos,
        {Map<String, Object?>? fuentes}) =>
    jsonEncode({
      'version': 1,
      'fuentes': fuentes ??
          {
            'sibus': {
              'nombre': 'SIBUS, Área Metropolitana de Barranquilla',
              'url': 'https://sibusoficial.ambq.gov.co/',
              'fecha': '2026-11-11',
            },
          },
      'puntos': puntos,
    });

Map<String, Object?> punto({
  String id = 'pv-1439',
  String nombre = 'PLAZA 43',
  double lat = 10.9829551,
  double lon = -74.7806758,
  String direccion = 'CLL 38 N 43 123',
  Object? fuente = 'sibus',
  Object? ejemplo,
  Object? horario,
  Object? municipio = 'Barranquilla',
}) =>
    {
      'id': id,
      'nombre': nombre,
      'lat': lat,
      'lon': lon,
      'direccion': direccion,
      if (municipio != null) 'municipio': municipio,
      if (horario != null) 'horario': horario,
      if (fuente != null) 'fuente': fuente,
      if (ejemplo != null) 'ejemplo': ejemplo,
    };

void main() {
  group('leerPuntosDeRecarga', () {
    test('lee un punto con su fuente citada', () {
      final puntos = leerPuntosDeRecarga(archivo([punto()]));

      expect(puntos, hasLength(1));
      final p = puntos.single;
      expect(p.id, 'pv-1439');
      expect(p.nombre, 'PLAZA 43');
      expect(p.lat, 10.9829551);
      expect(p.lon, -74.7806758);
      expect(p.direccion, 'CLL 38 N 43 123');
      expect(p.municipio, 'Barranquilla');
      expect(p.horario, isNull);
      expect(
        p.fuente,
        FuenteCitada(
          nombre: 'SIBUS, Área Metropolitana de Barranquilla',
          url: Uri.parse('https://sibusoficial.ambq.gov.co/'),
          fecha: DateTime.utc(2026, 11, 11),
        ),
      );
      expect(p.esEjemplo, isFalse);
    });

    test('un punto sin fuente vale solo con la marca de ejemplo', () {
      final p = leerPuntosDeRecarga(
        archivo([punto(fuente: null, ejemplo: true, horario: '7 a 19')]),
      ).single;

      expect(p.fuente, const FuenteEjemplo());
      expect(p.esEjemplo, isTrue);
      expect(p.horario, '7 a 19');
    });

    test('sin fuente ni marca de ejemplo el archivo no se acepta', () {
      expect(
        () => leerPuntosDeRecarga(archivo([punto(fuente: null)])),
        throwsA(isA<FormatException>()
            .having((e) => e.message, 'message', contains('pv-1439'))),
      );
    });

    test('fuente y marca de ejemplo a la vez tampoco', () {
      expect(
        () => leerPuntosDeRecarga(archivo([punto(ejemplo: true)])),
        throwsFormatException,
      );
    });

    test('ejemplo tiene que ser true, no otra cosa', () {
      expect(
        () => leerPuntosDeRecarga(
            archivo([punto(fuente: null, ejemplo: 'si')])),
        throwsFormatException,
      );
      expect(
        () => leerPuntosDeRecarga(
            archivo([punto(fuente: null, ejemplo: false)])),
        throwsFormatException,
      );
    });

    test('una fuente que no está en la lista no se acepta', () {
      expect(
        () => leerPuntosDeRecarga(archivo([punto(fuente: 'google')])),
        throwsFormatException,
      );
    });

    test('la fuente necesita nombre, url https y fecha', () {
      Map<String, Object?> con(Map<String, Object?> cambio) => {
            'sibus': {
              'nombre': 'SIBUS',
              'url': 'https://sibusoficial.ambq.gov.co/',
              'fecha': '2026-11-11',
              ...cambio,
            },
          };
      for (final mala in [
        con({'nombre': ''}),
        con({'url': 'http://sibusoficial.ambq.gov.co/'}),
        con({'url': 'no es url'}),
        con({'fecha': '11/11/2026'}),
        con({'fecha': null}),
      ]) {
        expect(
          () => leerPuntosDeRecarga(archivo([punto()], fuentes: mala)),
          throwsFormatException,
          reason: '$mala',
        );
      }
    });

    test('campos de texto vacíos o ausentes no se aceptan', () {
      for (final malo in [
        punto(id: ''),
        punto(nombre: '   '),
        punto(direccion: ''),
        {...punto()}..remove('direccion'),
        punto(horario: ''),
        punto(municipio: 3),
      ]) {
        expect(
          () => leerPuntosDeRecarga(archivo([malo])),
          throwsFormatException,
          reason: '$malo',
        );
      }
    });

    test('coordenadas fuera del mundo no se aceptan', () {
      for (final malo in [
        punto(lat: 91),
        punto(lon: -181),
        {...punto(), 'lat': '10.98'},
      ]) {
        expect(
          () => leerPuntosDeRecarga(archivo([malo])),
          throwsFormatException,
          reason: '$malo',
        );
      }
    });

    test('dos puntos con el mismo id no se aceptan', () {
      expect(
        () => leerPuntosDeRecarga(archivo([punto(), punto()])),
        throwsA(isA<FormatException>()
            .having((e) => e.message, 'message', contains('pv-1439'))),
      );
    });

    test('lo que no es el archivo esperado no se acepta', () {
      for (final malo in [
        'no es json',
        '[]',
        jsonEncode({'version': 2, 'fuentes': {}, 'puntos': []}),
        jsonEncode({'version': 1, 'fuentes': {}}),
        jsonEncode({'version': 1, 'fuentes': {}, 'puntos': [1]}),
      ]) {
        expect(() => leerPuntosDeRecarga(malo), throwsFormatException,
            reason: malo);
      }
    });
  });

  group('puntosCerca', () {
    // Sobre el mismo meridiano, un grado de latitud son 111.195 m con el
    // radio medio de la Tierra: 0,001 grados, 111 m.
    PuntoDeRecarga en(String id, double dLat) => PuntoDeRecarga(
          id: id,
          nombre: id,
          lat: 10.98 + dLat,
          lon: -74.78,
          direccion: 'Calle',
          fuente: const FuenteEjemplo(),
        );

    final lejos = en('lejos', 0.02); // 2,2 km
    final medio = en('medio', 0.005); // 556 m
    final cerca = en('cerca', -0.001); // 111 m

    test('deja solo los que están dentro del radio, del más cerca al más '
        'lejos, con su distancia', () {
      final cercanos = puntosCerca(
        [lejos, medio, cerca],
        lat: 10.98,
        lon: -74.78,
        radioMetros: 1000,
      );

      expect(cercanos.map((c) => c.punto.id), ['cerca', 'medio']);
      expect(cercanos.first.metros, closeTo(111.2, 0.5));
      expect(cercanos.last.metros, closeTo(556.0, 0.5));
    });

    test('el borde del radio cuenta como dentro', () {
      final borde = haversineMeters(10.98, -74.78, medio.lat, medio.lon);
      expect(
        puntosCerca([medio], lat: 10.98, lon: -74.78, radioMetros: borde),
        hasLength(1),
      );
    });

    test('sin nadie dentro del radio, la lista vacía', () {
      expect(
        puntosCerca([lejos], lat: 10.98, lon: -74.78, radioMetros: 1000),
        isEmpty,
      );
    });
  });

  group('haversineMeters', () {
    test('el mismo punto está a 0 m', () {
      expect(haversineMeters(10.98, -74.78, 10.98, -74.78), 0);
    });

    test('un grado de latitud son unos 111 km', () {
      expect(haversineMeters(10.98, -74.78, 11.98, -74.78),
          closeTo(111195, 1));
    });
  });
}
