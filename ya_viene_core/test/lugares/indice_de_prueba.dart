import 'dart:convert';

/// Un índice chico con el formato de `assets/data/lugares_*.json`, para
/// probar el buscador sin cargar el de verdad. Las calles son rectas de
/// juguete: lo que importa es cómo se cruzan.
///
/// Calle 72 va de oeste a este por la latitud 11.0000; las carreras 46 y 47
/// la cruzan de norte a sur, la 46 en -74.8050 y la 47 unos 109 m al oeste.
/// Hay una Calle 30 en Barranquilla y otra en Soledad.
String osmDePrueba() => jsonEncode({
      'fuente': {
        'nombre': 'OpenStreetMap',
        'autor': 'Colaboradores de OpenStreetMap',
        'licencia': 'ODbL 1.0',
        'url': 'https://www.openstreetmap.org/copyright',
        'fecha': '2026-11-11T00:00:00Z',
      },
      'barrios': [
        {
          'n': 'Barrio Abajo',
          'm': 'Barranquilla',
          'p': [10.9925, -74.7880],
        },
        {
          'n': 'El Prado',
          'm': 'Barranquilla',
          'p': [11.0000, -74.8000],
        },
        {
          'n': 'Prado Mar',
          'm': 'Puerto Colombia',
          'p': [11.0150, -74.8700],
          'a': ['Pradomar'],
        },
        {
          'n': 'Santa Mónica',
          'm': 'Barranquilla',
          'p': [10.9500, -74.8100],
        },
        {
          'n': 'La Campiña',
          'm': 'Barranquilla',
          'p': [11.0060, -74.8250],
        },
      ],
      'sitios': [
        {
          'n': 'Portal del Prado',
          'k': 'Centro comercial',
          'm': 'Barranquilla',
          'p': [10.9930, -74.7930],
        },
        {
          'n': 'Universidad del Norte',
          'k': 'Universidad',
          'm': 'Puerto Colombia',
          'p': [11.0190, -74.8510],
          'a': ['Uninorte'],
        },
      ],
      'vias': [
        {
          'n': 'Calle 72',
          'm': 'Barranquilla',
          'g': [
            codificar([
              [11.0000, -74.8200],
              [11.0000, -74.7900],
            ]),
          ],
        },
        {
          'n': 'Carrera 46',
          'm': 'Barranquilla',
          'g': [
            codificar([
              [11.0100, -74.8050],
              [10.9900, -74.8050],
            ]),
          ],
          'a': ['Avenida Olaya Herrera'],
        },
        {
          'n': 'Carrera 47',
          'm': 'Barranquilla',
          'g': [
            codificar([
              [11.0100, -74.8060],
              [10.9900, -74.8060],
            ]),
          ],
        },
        {
          'n': 'Carrera 50',
          'm': 'Barranquilla',
          // No llega a la 72: termina 500 m al sur.
          'g': [
            codificar([
              [10.9950, -74.8090],
              [10.9800, -74.8090],
            ]),
          ],
        },
        {
          'n': 'Calle 30',
          'm': 'Barranquilla',
          'g': [
            codificar([
              [10.9600, -74.8000],
              [10.9600, -74.7800],
            ]),
          ],
        },
        {
          'n': 'Calle 30',
          'm': 'Soledad',
          'g': [
            codificar([
              [10.9100, -74.7800],
              [10.9100, -74.7600],
            ]),
          ],
        },
      ],
    });

String potDePrueba() => jsonEncode({
      'fuente': {
        'nombre': 'Barrios de Barranquilla según POT',
        'autor': 'Alcaldía Distrital de Barranquilla',
        'licencia': 'CC BY-SA 4.0',
        'url': 'https://www.datos.gov.co/d/qui6-qeux',
        'fecha': '2021-12-30',
      },
      'barrios': [
        {
          'n': 'Boyaca',
          'm': 'Barranquilla',
          'p': [10.9550, -74.7950],
        },
      ],
    });

/// Polilínea codificada de Google, precisión 1e-5, como la escribe
/// `tool/lugares/construir.mjs`.
String codificar(List<List<double>> puntos) {
  final salida = StringBuffer();
  var latPrevia = 0, lonPrevia = 0;
  void numero(int v) {
    var x = v < 0 ? ~(v << 1) : v << 1;
    while (x >= 0x20) {
      salida.writeCharCode((0x20 | (x & 0x1f)) + 63);
      x >>= 5;
    }
    salida.writeCharCode(x + 63);
  }

  for (final p in puntos) {
    final lat = (p[0] * 1e5).round(), lon = (p[1] * 1e5).round();
    numero(lat - latPrevia);
    numero(lon - lonPrevia);
    latPrevia = lat;
    lonPrevia = lon;
  }
  return salida.toString();
}
