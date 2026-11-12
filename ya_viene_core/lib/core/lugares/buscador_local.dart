import 'dart:convert';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart';

import '../models/route_trajectory.dart';
import 'buscador_de_lugares.dart';
import 'lugar.dart';
import 'texto_lugar.dart';

/// Los índices que escribe `tool/lugares/construir.mjs`, uno por licencia
/// (D25): OpenStreetMap (ODbL) y los barrios del POT (CC BY-SA 4.0).
const kLugaresAssets = [
  'packages/ya_viene_core/assets/data/lugares_osm.json',
  'packages/ya_viene_core/assets/data/lugares_pot.json',
];

/// Busca en el índice que viene dentro de la app (D25): sin red, y lo que
/// se escribe no sale del teléfono (Ley 1581).
///
/// Entiende nombres de barrios, vías y sitios, y direcciones de la
/// nomenclatura: «Calle 72 con 46» es la esquina y «Calle 72 # 46-20», la
/// placa, 20 m desde esa esquina hacia la 47.
class BuscadorLocal implements BuscadorDeLugares {
  BuscadorLocal._(this._entradas, this._vias, this.atribucion);

  /// Arma el buscador desde el texto de cada índice. Las pruebas lo usan
  /// con índices de juguete; la app, por [cargar].
  factory BuscadorLocal.desdeJson(List<String> indices) {
    final entradas = <_Entrada>[];
    final vias = <_Via>[];
    final fuentes = <String>[];
    for (final texto in indices) {
      final indice = jsonDecode(texto) as Map<String, dynamic>;
      final fuente = indice['fuente'] as Map<String, dynamic>;
      fuentes.add('${fuente['autor']} (${fuente['licencia']})');

      for (final b in _lista(indice['barrios'])) {
        entradas.add(_Entrada(
          nombre: b['n'] as String,
          variantes: _variantes(b),
          tipo: TipoLugar.barrio,
          contexto: 'Barrio, ${b['m']}',
          punto: _punto(b['p']),
        ));
      }
      for (final s in _lista(indice['sitios'])) {
        entradas.add(_Entrada(
          nombre: s['n'] as String,
          variantes: _variantes(s),
          tipo: TipoLugar.sitio,
          contexto: '${s['k']}, ${s['m']}',
          punto: _punto(s['p']),
        ));
      }
      for (final v in _lista(indice['vias'])) {
        final via = _Via(
          nombre: v['n'] as String,
          municipio: v['m'] as String,
          tramos: [
            for (final g in v['g'] as List<dynamic>) _decodificar(g as String)
          ],
        );
        vias.add(via);
        entradas.add(_Entrada(
          nombre: via.nombre,
          variantes: _variantes(v),
          tipo: TipoLugar.via,
          contexto: '${via.clase}, ${via.municipio}',
          via: via,
        ));
      }
    }
    return BuscadorLocal._(entradas, vias, '© ${fuentes.join(' y ')}');
  }

  /// Lee los índices de la app y los prepara en otro hilo: son cientos de
  /// kilobytes de JSON y la pantalla no debe trabarse mientras tanto.
  static Future<BuscadorLocal> cargar([AssetBundle? bundle]) async {
    final assets = bundle ?? rootBundle;
    final textos = [
      for (final ruta in kLugaresAssets) await assets.loadString(ruta),
    ];
    return Isolate.run(() => BuscadorLocal.desdeJson(textos));
  }

  final List<_Entrada> _entradas;
  final List<_Via> _vias;

  @override
  final String atribucion;

  @override
  Future<List<Sugerencia>> buscar(
    String consulta, {
    int maximo = 8,
    GeoPoint? sesgo,
  }) async {
    final palabras = palabrasDe(consulta);
    if (palabras.isEmpty || maximo <= 0) return const [];

    final direccion = _Direccion.leer(palabras);
    final resultados = <Sugerencia>[
      if (direccion != null) ..._esquinas(direccion, sesgo),
    ];
    final porNombre = direccion?.viaSola ?? palabras;
    resultados.addAll(_porNombre(porNombre, sesgo));

    final vistas = <Lugar>{};
    return [
      for (final s in resultados)
        if (vistas.add(s.lugar)) s,
    ].take(maximo).toList();
  }

  // ── Por nombre ─────────────────────────────────────────────────────────

  List<Sugerencia> _porNombre(List<String> consulta, GeoPoint? sesgo) {
    final encontradas = <({_Entrada entrada, _Parecido parecido})>[];
    for (final entrada in _entradas) {
      _Parecido? mejor;
      for (final variante in entrada.variantes) {
        final p = _Parecido.de(consulta, variante);
        if (p != null && (mejor == null || p.compareTo(mejor) < 0)) mejor = p;
      }
      if (mejor != null) encontradas.add((entrada: entrada, parecido: mejor));
    }

    final conPunto = [
      for (final e in encontradas)
        (
          entrada: e.entrada,
          parecido: e.parecido,
          punto: e.entrada.punto ?? e.entrada.via!.puntoPara(sesgo),
        ),
    ];
    final lejania = sesgo == null ? null : _lejaniaDesde(sesgo);
    conPunto.sort((a, b) {
      final porParecido = a.parecido.compareTo(b.parecido);
      if (porParecido != 0) return porParecido;
      if (lejania != null) {
        final porCerca = lejania(a.punto).compareTo(lejania(b.punto));
        if (porCerca != 0) return porCerca;
      }
      final porTipo = a.entrada.tipo.index.compareTo(b.entrada.tipo.index);
      if (porTipo != 0) return porTipo;
      return a.entrada.nombre.compareTo(b.entrada.nombre);
    });

    return [
      for (final e in conPunto)
        Sugerencia(
          lugar: Lugar(
            punto: e.punto,
            origen: OrigenLugar.sitio,
            nombre: e.entrada.nombre,
          ),
          tipo: e.entrada.tipo,
          contexto: e.entrada.contexto,
        ),
    ];
  }

  // ── Direcciones ────────────────────────────────────────────────────────

  /// Las esquinas (o placas) que nombra [d], la más cerca del sesgo primero.
  List<Sugerencia> _esquinas(_Direccion d, GeoPoint? sesgo) {
    final otroNumero = d.otroNumero;
    if (otroNumero == null) return const [];
    final principales = [
      for (final v in _vias)
        if (v.clase == d.clase && v.numero == d.numero) v,
    ];
    final esquinas = <({Sugerencia sugerencia, bool exacta})>[];
    for (final a in principales) {
      for (final b in _vias) {
        if (b.municipio != a.municipio || b.numero == null) continue;
        final claseOk = d.otraClase == null
            ? _cruzan(a.clase, b.clase)
            : b.clase == d.otraClase;
        final exacta = b.numero == otroNumero;
        final numeroOk = exacta ||
            (d.otroNumeroIncompleto && b.numero!.startsWith(otroNumero));
        if (!claseOk || !numeroOk) continue;

        final cruce = a.cruceCon(b);
        if (cruce == null) continue;

        final placa = d.placa;
        final GeoPoint punto;
        final String nombre;
        final String contexto;
        if (placa == null) {
          punto = cruce;
          nombre = '${a.nombre} con ${b.nombre}';
          contexto = 'Esquina, ${a.municipio}';
        } else {
          punto = _caminarHaciaLaSiguiente(a, b, cruce, placa);
          nombre = '${a.nombre} # ${b.numero!.toUpperCase()}-$placa';
          contexto = 'Dirección, ${a.municipio}';
        }
        esquinas.add((
          sugerencia: Sugerencia(
            lugar:
                Lugar(punto: punto, origen: OrigenLugar.sitio, nombre: nombre),
            tipo: TipoLugar.cruce,
            contexto: contexto,
          ),
          exacta: exacta,
        ));
      }
    }

    final lejania = sesgo == null ? null : _lejaniaDesde(sesgo);
    esquinas.sort((x, y) {
      if (x.exacta != y.exacta) return x.exacta ? -1 : 1;
      if (lejania != null) {
        final porCerca = lejania(x.sugerencia.lugar.punto)
            .compareTo(lejania(y.sugerencia.lugar.punto));
        if (porCerca != 0) return porCerca;
      }
      return x.sugerencia.nombre.compareTo(y.sugerencia.nombre);
    });
    return [for (final e in esquinas) e.sugerencia];
  }

  /// La placa «46-20» está 20 m por la vía [a] desde la esquina con la 46,
  /// hacia la 47. Si la 47 no está en el índice se camina lejos de la 45; si
  /// tampoco, se queda en la esquina, que es lo único que se sabe.
  GeoPoint _caminarHaciaLaSiguiente(_Via a, _Via b, GeoPoint cruce, int placa) {
    final base = int.tryParse(RegExp(r'^\d+').stringMatch(b.numero!)!)!;
    GeoPoint? esquinaCon(int numero) {
      for (final v in _vias) {
        if (v.municipio == a.municipio &&
            v.clase == b.clase &&
            v.numero == '$numero') {
          final c = a.cruceCon(v);
          if (c != null) return c;
        }
      }
      return null;
    }

    final siguiente = esquinaCon(base + 1);
    final anterior = siguiente == null ? esquinaCon(base - 1) : null;
    if (siguiente == null && anterior == null) return cruce;
    return a.caminar(cruce, placa.toDouble(),
        hacia: siguiente, lejosDe: anterior);
  }
}

/// Qué clases de vía se cruzan en la cuadrícula de Barranquilla: las
/// calles y diagonales van de oriente a occidente, las carreras y
/// transversales de norte a sur. Una avenida puede ir en cualquiera.
bool _cruzan(String a, String b) {
  const esteOeste = {'Calle', 'Diagonal'};
  const norteSur = {'Carrera', 'Transversal'};
  if (a == 'Avenida' || b == 'Avenida') return a != b;
  return (esteOeste.contains(a) && norteSur.contains(b)) ||
      (norteSur.contains(a) && esteOeste.contains(b));
}

// ── El índice ────────────────────────────────────────────────────────────

class _Entrada {
  _Entrada({
    required this.nombre,
    required this.variantes,
    required this.tipo,
    required this.contexto,
    this.punto,
    this.via,
  });

  final String nombre;

  /// Las palabras del nombre y de cada otro nombre («Uninorte»).
  final List<List<String>> variantes;
  final TipoLugar tipo;
  final String contexto;
  final GeoPoint? punto;
  final _Via? via;
}

const _clasesDeVia = {
  'calle': 'Calle',
  'carrera': 'Carrera',
  'avenida': 'Avenida',
  'diagonal': 'Diagonal',
  'transversal': 'Transversal',
};

final _numeroDeVia = RegExp(r'^\d+[a-z]*$');

class _Via {
  _Via({required this.nombre, required this.municipio, required this.tramos}) {
    final palabras = palabrasDe(nombre);
    clase = _clasesDeVia[palabras.first] ?? 'Vía';
    numero = palabras.length == 2 &&
            _clasesDeVia.containsKey(palabras.first) &&
            _numeroDeVia.hasMatch(palabras[1])
        ? palabras[1]
        : null;
  }

  final String nombre;
  final String municipio;

  /// Cada tramo en metros sobre [_plano], x e y alternados.
  final List<Float64List> tramos;

  /// «Calle», «Carrera»... o «Vía» si el nombre no la dice («Circunvalar»).
  late final String clase;

  /// «72», «72b»; null si la vía no se nombra con número.
  late final String? numero;

  /// Su punto más cerca de [sesgo]; sin sesgo, la mitad del tramo más
  /// largo, que es donde la gente la piensa.
  GeoPoint puntoPara(GeoPoint? sesgo) {
    if (sesgo == null) {
      Float64List? largo;
      var mayor = -1.0;
      for (final t in tramos) {
        final l = _largo(t);
        if (l > mayor) {
          mayor = l;
          largo = t;
        }
      }
      return _plano.aGeo(_puntoA(largo!, mayor / 2));
    }
    final s = _plano.aPlano(sesgo);
    return _plano.aGeo(_masCerca(s).punto);
  }

  /// Dónde se cruza con [otra]: el punto donde más se acercan, si están a
  /// menos de 30 m (las dos líneas de OSM van por el centro de cada calle y
  /// a veces no se tocan en la esquina).
  GeoPoint? cruceCon(_Via otra) {
    const tolerancia = 30.0;
    ({double x, double y})? mejor;
    var menor = tolerancia;
    for (final a in tramos) {
      for (final b in otra.tramos) {
        if (!_cajasCerca(a, b, tolerancia)) continue;
        for (var i = 0; i + 3 < a.length; i += 2) {
          for (var j = 0; j + 3 < b.length; j += 2) {
            final c = _acercamiento(
              a[i],
              a[i + 1],
              a[i + 2],
              a[i + 3],
              b[j],
              b[j + 1],
              b[j + 2],
              b[j + 3],
            );
            if (c.distancia < menor) {
              menor = c.distancia;
              mejor = c.punto;
            }
          }
        }
      }
    }
    return mejor == null ? null : _plano.aGeo(mejor);
  }

  /// El punto a [metros] de [desde] por esta vía, hacia [hacia] o lejos de
  /// [lejosDe].
  GeoPoint caminar(
    GeoPoint desde,
    double metros, {
    GeoPoint? hacia,
    GeoPoint? lejosDe,
  }) {
    final origen = _masCerca(_plano.aPlano(desde));
    final tramo = tramos[origen.tramo];
    final total = _largo(tramo);
    final adelante = _puntoA(tramo, math.min(total, origen.avance + metros));
    final atras = _puntoA(tramo, math.max(0, origen.avance - metros));
    final ({double x, double y}) elegido;
    if (hacia != null) {
      final h = _plano.aPlano(hacia);
      elegido = _d2(adelante, h) <= _d2(atras, h) ? adelante : atras;
    } else {
      final l = _plano.aPlano(lejosDe!);
      elegido = _d2(adelante, l) >= _d2(atras, l) ? adelante : atras;
    }
    return _plano.aGeo(elegido);
  }

  ({int tramo, double avance, ({double x, double y}) punto}) _masCerca(
    ({double x, double y}) p,
  ) {
    var mejorTramo = 0;
    var mejorAvance = 0.0;
    var mejorPunto = (x: tramos[0][0], y: tramos[0][1]);
    var menor = double.infinity;
    for (var t = 0; t < tramos.length; t++) {
      final tramo = tramos[t];
      var avance = 0.0;
      for (var i = 0; i + 3 < tramo.length; i += 2) {
        final ax = tramo[i], ay = tramo[i + 1];
        final dx = tramo[i + 2] - ax, dy = tramo[i + 3] - ay;
        final l2 = dx * dx + dy * dy;
        final f = l2 == 0
            ? 0.0
            : (((p.x - ax) * dx + (p.y - ay) * dy) / l2).clamp(0.0, 1.0);
        final q = (x: ax + f * dx, y: ay + f * dy);
        final d = _d2(p, q);
        if (d < menor) {
          menor = d;
          mejorTramo = t;
          mejorAvance = avance + f * math.sqrt(l2);
          mejorPunto = q;
        }
        avance += math.sqrt(l2);
      }
    }
    return (tramo: mejorTramo, avance: mejorAvance, punto: mejorPunto);
  }
}

// ── Lo que escribe la persona ────────────────────────────────────────────

/// Una dirección de la nomenclatura: «calle 72 con 46», «cl 72 # 46-20».
class _Direccion {
  _Direccion({
    required this.clase,
    required this.numero,
    required this.viaSola,
    this.otraClase,
    this.otroNumero,
    this.otroNumeroIncompleto = false,
    this.placa,
  });

  final String clase;
  final String numero;

  /// Las palabras de la primera vía, para sugerirla también por nombre.
  final List<String> viaSola;
  final String? otraClase;

  /// null mientras la persona va en el conector («calle 72 con»).
  final String? otroNumero;

  /// El número de la otra vía es lo último escrito: puede faltarle.
  final bool otroNumeroIncompleto;
  final int? placa;

  static const _conectores = {'con', 'y', numeral};

  /// Lee «clase número conector [clase] número [placa]»; null si no es una
  /// dirección.
  static _Direccion? leer(List<String> p) {
    if (p.length < 3) return null;
    final clase = _clasesDeVia[p[0]];
    if (clase == null || !_numeroDeVia.hasMatch(p[1])) return null;
    if (!_conectores.contains(p[2])) return null;
    final viaSola = p.sublist(0, 2);

    var i = 3;
    String? otraClase;
    if (i < p.length && _clasesDeVia.containsKey(p[i])) {
      otraClase = _clasesDeVia[p[i++]];
    }
    if (i == p.length) {
      return _Direccion(clase: clase, numero: p[1], viaSola: viaSola);
    }
    if (!_numeroDeVia.hasMatch(p[i])) return null;
    final otroNumero = p[i++];
    int? placa;
    if (i < p.length) {
      placa = int.tryParse(p[i++]);
      if (placa == null || i < p.length) return null;
    }
    return _Direccion(
      clase: clase,
      numero: p[1],
      viaSola: viaSola,
      otraClase: otraClase,
      otroNumero: otroNumero,
      otroNumeroIncompleto: placa == null,
      placa: placa,
    );
  }
}

/// Qué tan bien una consulta encaja en un nombre; menor es mejor.
class _Parecido implements Comparable<_Parecido> {
  _Parecido(this.nivel, this.sobrantes);

  /// 0 el nombre exacto, 1 todas las palabras exactas, 2 la última a
  /// medias (se está escribiendo), 3 alguna con una letra mal.
  final int nivel;

  /// Palabras del nombre que la consulta no nombró: «Calle 72» le gana a
  /// «Calle 72B» con la consulta «calle 72».
  final int sobrantes;

  static _Parecido? de(List<String> consulta, List<String> nombre) {
    var nivel = 1;
    final usadas = List<bool>.filled(nombre.length, false);
    for (var i = 0; i < consulta.length; i++) {
      final q = consulta[i];
      final ultima = i == consulta.length - 1;
      var encontrada = -1;
      var calidad = 4;
      for (var j = 0; j < nombre.length && calidad > 1; j++) {
        if (usadas[j]) continue;
        final n = nombre[j];
        if (n == q) {
          encontrada = j;
          calidad = 1;
        } else if (calidad > 2 && ultima && n.startsWith(q)) {
          encontrada = j;
          calidad = 2;
        } else if (calidad > 3 && casiIgual(q, n)) {
          encontrada = j;
          calidad = 3;
        }
      }
      if (encontrada < 0) return null;
      usadas[encontrada] = true;
      if (calidad > nivel) nivel = calidad;
    }
    final sobrantes = nombre.length - consulta.length;
    return _Parecido(nivel == 1 && sobrantes == 0 ? 0 : nivel, sobrantes);
  }

  @override
  int compareTo(_Parecido otro) => nivel != otro.nivel
      ? nivel.compareTo(otro.nivel)
      : sobrantes.compareTo(otro.sobrantes);
}

// ── Geometría ────────────────────────────────────────────────────────────

/// Plano local en metros, centrado en Barranquilla: a escala del área
/// metropolitana (30 km) el error frente a la esfera es de milímetros.
class _Plano {
  const _Plano(this.lat0);

  final double lat0;

  static const _radio = 6371000.0;
  double get _kLat => math.pi / 180 * _radio;
  double get _kLon => _kLat * math.cos(lat0 * math.pi / 180);

  ({double x, double y}) aPlano(GeoPoint p) =>
      (x: p.lon * _kLon, y: p.lat * _kLat);

  GeoPoint aGeo(({double x, double y}) p) => GeoPoint(
        lat: _redondear(p.y / _kLat),
        lon: _redondear(p.x / _kLon),
      );

  /// A 1e-7 grados (1 cm): lo que pasa por el plano vuelve sin el ruido de
  /// la coma flotante, y el punto de un barrio sale igual que en el índice.
  static double _redondear(double grados) => (grados * 1e7).round() / 1e7;
}

/// Metros al cuadrado desde [sesgo]: para ordenar no hace falta la raíz.
double Function(GeoPoint) _lejaniaDesde(GeoPoint sesgo) {
  final s = _plano.aPlano(sesgo);
  return (p) => _d2(_plano.aPlano(p), s);
}

const _plano = _Plano(11.0);

double _d2(({double x, double y}) a, ({double x, double y}) b) {
  final dx = a.x - b.x, dy = a.y - b.y;
  return dx * dx + dy * dy;
}

double _largo(Float64List t) {
  var l = 0.0;
  for (var i = 0; i + 3 < t.length; i += 2) {
    final dx = t[i + 2] - t[i], dy = t[i + 3] - t[i + 1];
    l += math.sqrt(dx * dx + dy * dy);
  }
  return l;
}

({double x, double y}) _puntoA(Float64List t, double avance) {
  var resto = avance;
  for (var i = 0; i + 3 < t.length; i += 2) {
    final dx = t[i + 2] - t[i], dy = t[i + 3] - t[i + 1];
    final l = math.sqrt(dx * dx + dy * dy);
    if (resto <= l && l > 0) {
      final f = resto / l;
      return (x: t[i] + f * dx, y: t[i + 1] + f * dy);
    }
    resto -= l;
  }
  return (x: t[t.length - 2], y: t[t.length - 1]);
}

bool _cajasCerca(Float64List a, Float64List b, double margen) {
  double minX(Float64List t) {
    var m = double.infinity;
    for (var i = 0; i < t.length; i += 2) {
      if (t[i] < m) m = t[i];
    }
    return m;
  }

  double maxX(Float64List t) {
    var m = -double.infinity;
    for (var i = 0; i < t.length; i += 2) {
      if (t[i] > m) m = t[i];
    }
    return m;
  }

  double minY(Float64List t) {
    var m = double.infinity;
    for (var i = 1; i < t.length; i += 2) {
      if (t[i] < m) m = t[i];
    }
    return m;
  }

  double maxY(Float64List t) {
    var m = -double.infinity;
    for (var i = 1; i < t.length; i += 2) {
      if (t[i] > m) m = t[i];
    }
    return m;
  }

  return minX(a) - margen <= maxX(b) &&
      minX(b) - margen <= maxX(a) &&
      minY(a) - margen <= maxY(b) &&
      minY(b) - margen <= maxY(a);
}

/// Lo más que se acercan los segmentos AB y CD, y dónde (sobre AB): el
/// cruce si se cortan.
({double distancia, ({double x, double y}) punto}) _acercamiento(
  double ax,
  double ay,
  double bx,
  double by, //
  double cx,
  double cy,
  double dx,
  double dy,
) {
  final rX = bx - ax, rY = by - ay, sX = dx - cx, sY = dy - cy;
  final den = rX * sY - rY * sX;
  if (den != 0) {
    final t = ((cx - ax) * sY - (cy - ay) * sX) / den;
    final u = ((cx - ax) * rY - (cy - ay) * rX) / den;
    if (t >= 0 && t <= 1 && u >= 0 && u <= 1) {
      return (distancia: 0, punto: (x: ax + t * rX, y: ay + t * rY));
    }
  }
  ({double x, double y}) sobre(
    double px,
    double py,
    double ox,
    double oy,
    double vx,
    double vy,
  ) {
    final l2 = vx * vx + vy * vy;
    final f = l2 == 0
        ? 0.0
        : (((px - ox) * vx + (py - oy) * vy) / l2).clamp(0.0, 1.0);
    return (x: ox + f * vx, y: oy + f * vy);
  }

  // Los cuatro extremos contra el otro segmento; el punto se da sobre AB.
  final candidatos = [
    ((x: ax, y: ay), sobre(ax, ay, cx, cy, sX, sY)),
    ((x: bx, y: by), sobre(bx, by, cx, cy, sX, sY)),
    (sobre(cx, cy, ax, ay, rX, rY), (x: cx, y: cy)),
    (sobre(dx, dy, ax, ay, rX, rY), (x: dx, y: dy)),
  ];
  var mejor = candidatos.first;
  var menor = _d2(mejor.$1, mejor.$2);
  for (final c in candidatos.skip(1)) {
    final d = _d2(c.$1, c.$2);
    if (d < menor) {
      menor = d;
      mejor = c;
    }
  }
  return (distancia: math.sqrt(menor), punto: mejor.$1);
}

// ── Lectura del JSON ─────────────────────────────────────────────────────

List<Map<String, dynamic>> _lista(Object? valor) => [
      for (final v in (valor as List<dynamic>? ?? const []))
        v as Map<String, dynamic>
    ];

GeoPoint _punto(Object? par) {
  final p = par as List<dynamic>;
  return GeoPoint(lat: (p[0] as num).toDouble(), lon: (p[1] as num).toDouble());
}

List<List<String>> _variantes(Map<String, dynamic> lugar) => [
      palabrasDe(lugar['n'] as String),
      for (final a in lugar['a'] as List<dynamic>? ?? const [])
        palabrasDe(a as String),
    ];

/// Polilínea codificada de Google, precisión 1e-5, llevada al plano.
Float64List _decodificar(String g) {
  final xy = <double>[];
  var i = 0, lat = 0, lon = 0;
  int numero() {
    var resultado = 0, corrimiento = 0, b = 0;
    do {
      b = g.codeUnitAt(i++) - 63;
      resultado |= (b & 0x1f) << corrimiento;
      corrimiento += 5;
    } while (b >= 0x20);
    return (resultado & 1) != 0 ? ~(resultado >> 1) : resultado >> 1;
  }

  while (i < g.length) {
    lat += numero();
    lon += numero();
    final p = _plano.aPlano(GeoPoint(lat: lat / 1e5, lon: lon / 1e5));
    xy
      ..add(p.x)
      ..add(p.y);
  }
  return Float64List.fromList(xy);
}
