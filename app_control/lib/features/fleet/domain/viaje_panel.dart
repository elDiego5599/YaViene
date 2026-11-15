/// Un punto del mapa: el centro de una zona de 4×4 celdas de D17.
typedef PuntoZona = ({double lat, double lng});

/// Los viajes buscados de la empresa (D20): pares origen a destino con su
/// total. El servidor solo manda los que llegan a 5 o más en un día, y los
/// puntos ya vienen redondeados a la zona: aquí no hay nada personal.
class ReporteViajes {
  ReporteViajes(this.pares) : zonas = _rotular(pares);

  factory ReporteViajes.fromJson(Map<String, dynamic> json) => ReporteViajes([
    for (final p in json['pares'] as List<dynamic>)
      ParViaje.fromJson(p as Map<String, dynamic>),
  ]);

  static final vacio = ReporteViajes(const []);

  /// De más a menos viajes, como los manda el servidor.
  final List<ParViaje> pares;

  /// Las zonas que aparecen, rotuladas A, B, C por lo que mueven. El mapa no
  /// lleva nombres de sitios (regla del producto), así que la letra es el
  /// único nombre que la zona tiene.
  final List<ZonaViaje> zonas;

  int get total => pares.fold(0, (suma, p) => suma + p.total);

  /// El rótulo de la zona de salida y el de la de llegada de [par].
  (String, String) etiquetasDe(ParViaje par) =>
      (_zonaEn(par.origen).etiqueta, _zonaEn(par.destino).etiqueta);

  ZonaViaje _zonaEn(PuntoZona punto) =>
      zonas.firstWhere((z) => z.lat == punto.lat && z.lng == punto.lng);

  static List<ZonaViaje> _rotular(List<ParViaje> pares) {
    final salen = <PuntoZona, int>{};
    final llegan = <PuntoZona, int>{};
    for (final par in pares) {
      salen.update(par.origen, (n) => n + par.total, ifAbsent: () => par.total);
      llegan.update(
        par.destino,
        (n) => n + par.total,
        ifAbsent: () => par.total,
      );
      salen.putIfAbsent(par.destino, () => 0);
      llegan.putIfAbsent(par.origen, () => 0);
    }
    // El orden de llegada de las claves rompe los empates.
    final puntos = salen.keys.toList();
    final orden = [...puntos]
      ..sort((a, b) {
        final pesoA = salen[a]! + llegan[a]!;
        final pesoB = salen[b]! + llegan[b]!;
        return pesoB != pesoA
            ? pesoB.compareTo(pesoA)
            : puntos.indexOf(a).compareTo(puntos.indexOf(b));
      });
    return [
      for (final (i, p) in orden.indexed)
        ZonaViaje(
          etiqueta: etiquetaZona(i),
          lat: p.lat,
          lng: p.lng,
          salen: salen[p]!,
          llegan: llegan[p]!,
        ),
    ];
  }
}

class ParViaje {
  const ParViaje({
    required this.origen,
    required this.destino,
    required this.total,
  });

  factory ParViaje.fromJson(Map<String, dynamic> json) => ParViaje(
    origen: _punto(json['origen']),
    destino: _punto(json['destino']),
    total: (json['total'] as num).toInt(),
  );

  static PuntoZona _punto(Object? json) {
    final mapa = json as Map<String, dynamic>;
    return (
      lat: (mapa['lat'] as num).toDouble(),
      lng: (mapa['lng'] as num).toDouble(),
    );
  }

  final PuntoZona origen;
  final PuntoZona destino;
  final int total;

  /// Salió y llegó a la misma zona: no hay línea que dibujar.
  bool get dentroDeLaZona => origen == destino;
}

class ZonaViaje {
  const ZonaViaje({
    required this.etiqueta,
    required this.lat,
    required this.lng,
    required this.salen,
    required this.llegan,
  });

  final String etiqueta;
  final double lat;
  final double lng;

  /// Viajes que salen de esta zona y viajes que llegan a ella.
  final int salen;
  final int llegan;
}

/// A, B, … Z, AA, AB, … como las columnas de una hoja de cálculo.
String etiquetaZona(int indice) {
  var n = indice + 1;
  var letras = '';
  while (n > 0) {
    final resto = (n - 1) % 26;
    letras = String.fromCharCode(65 + resto) + letras;
    n = (n - 1) ~/ 26;
  }
  return letras;
}

/// «6 a. m. a 9 a. m.»: las tres horas de Bogotá que cubre la [franja] 0 a 7.
String franjaLabel(int franja) =>
    '${_hora(franja * 3)} a ${_hora(franja * 3 + 3)}';

String _hora(int hora) {
  final h = hora % 24;
  return '${h % 12 == 0 ? 12 : h % 12} ${h < 12 ? 'a. m.' : 'p. m.'}';
}
