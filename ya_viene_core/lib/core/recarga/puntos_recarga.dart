// Dónde recargar la tarjeta del bus (D21).
//
// Cada punto dice de dónde salió: una fuente pública citada, con su nombre,
// su dirección web y la fecha en que se consultó, o la marca de ejemplo. Un
// punto sin ninguna de las dos no entra: el archivo entero se rechaza, para
// que un dato sin origen no llegue nunca a la pantalla con cara de real.
import 'dart:convert';

import 'package:equatable/equatable.dart';

import '../geo/distancia.dart';

/// De dónde salió un punto de recarga.
sealed class Fuente {
  const Fuente();
}

/// Una fuente pública que se puede citar: quién la publica, dónde y cuándo
/// se consultó. La fecha va en la ficha, porque los puntos cambian.
final class FuenteCitada extends Fuente with Equatable {
  const FuenteCitada({
    required this.nombre,
    required this.url,
    required this.fecha,
  });

  final String nombre;
  final Uri url;

  /// Día de la consulta, en UTC y sin hora.
  final DateTime fecha;

  @override
  List<Object?> get props => [nombre, url, fecha];
}

/// Un punto puesto para enseñar la función, sin fuente detrás. La ficha lo
/// dice con todas las letras.
final class FuenteEjemplo extends Fuente {
  const FuenteEjemplo();

  @override
  bool operator ==(Object other) => other is FuenteEjemplo;

  @override
  int get hashCode => (FuenteEjemplo).hashCode;
}

/// Un sitio donde se recarga la tarjeta del bus.
final class PuntoDeRecarga extends Equatable {
  const PuntoDeRecarga({
    required this.id,
    required this.nombre,
    required this.lat,
    required this.lon,
    required this.direccion,
    required this.fuente,
    this.municipio,
    this.horario,
  });

  final String id;

  /// Como lo escribe la fuente (los del AMB, en mayúsculas).
  final String nombre;
  final double lat;
  final double lon;
  final String direccion;
  final String? municipio;

  /// Solo si la fuente lo da; los del AMB no lo traen.
  final String? horario;
  final Fuente fuente;

  bool get esEjemplo => fuente is FuenteEjemplo;

  @override
  List<Object?> get props =>
      [id, nombre, lat, lon, direccion, municipio, horario, fuente];
}

/// Un punto y los metros en línea recta que lo separan de donde se mide.
typedef PuntoCercano = ({PuntoDeRecarga punto, double metros});

/// Los [puntos] a [radioMetros] o menos de ([lat], [lon]), del más cerca al
/// más lejos.
///
/// En línea recta: es para saber qué hay a pie alrededor, no un recorrido.
List<PuntoCercano> puntosCerca(
  Iterable<PuntoDeRecarga> puntos, {
  required double lat,
  required double lon,
  required double radioMetros,
}) {
  final cercanos = <PuntoCercano>[
    for (final punto in puntos)
      if (haversineMeters(lat, lon, punto.lat, punto.lon) case final metros
          when metros <= radioMetros)
        (punto: punto, metros: metros),
  ]..sort((a, b) => a.metros.compareTo(b.metros));
  return cercanos;
}

/// Lee el archivo de puntos de recarga (`puntos_recarga.json`).
///
/// Lanza [FormatException] ante cualquier cosa fuera del esquema: un punto
/// sin fuente ni marca de ejemplo, con las dos, con una fuente que no está
/// en la lista, con un texto vacío, con coordenadas imposibles o con un id
/// repetido. Se rechaza el archivo entero y no solo el punto: el archivo se
/// genera con `app_pasajero/tool/puntos_recarga_desde_kml.py` y un punto malo es un
/// error de ese paso, que se tiene que ver.
List<PuntoDeRecarga> leerPuntosDeRecarga(String texto) {
  final Object? raiz;
  try {
    raiz = jsonDecode(texto);
  } on FormatException catch (e) {
    throw FormatException('Puntos de recarga: no es JSON (${e.message})');
  }
  if (raiz is! Map<String, Object?>) {
    throw const FormatException('Puntos de recarga: se esperaba un objeto');
  }
  if (raiz['version'] != 1) {
    throw FormatException(
        'Puntos de recarga: versión ${raiz['version']} desconocida');
  }
  final fuentes = _leerFuentes(raiz['fuentes']);
  final lista = raiz['puntos'];
  if (lista is! List<Object?>) {
    throw const FormatException('Puntos de recarga: falta la lista de puntos');
  }

  final puntos = <PuntoDeRecarga>[];
  final vistos = <String>{};
  for (final (i, crudo) in lista.indexed) {
    final punto = _leerPunto(crudo, i, fuentes);
    if (!vistos.add(punto.id)) {
      throw FormatException(
          'Puntos de recarga: el id ${punto.id} está repetido');
    }
    puntos.add(punto);
  }
  return puntos;
}

Map<String, FuenteCitada> _leerFuentes(Object? crudo) {
  if (crudo is! Map<String, Object?>) {
    throw const FormatException('Puntos de recarga: faltan las fuentes');
  }
  return {
    for (final MapEntry(:key, :value) in crudo.entries)
      key: _leerFuente(key, value),
  };
}

FuenteCitada _leerFuente(String id, Object? crudo) {
  String donde() => 'la fuente $id';
  if (crudo is! Map<String, Object?>) {
    throw FormatException('Puntos de recarga: ${donde()} no es un objeto');
  }
  final url = Uri.tryParse(_texto(crudo, 'url', donde));
  if (url == null || url.scheme != 'https' || url.host.isEmpty) {
    throw FormatException('Puntos de recarga: ${donde()} sin url https');
  }
  final fechaTexto = _texto(crudo, 'fecha', donde);
  final fecha = RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(fechaTexto)
      ? DateTime.tryParse('${fechaTexto}T00:00:00Z')
      : null;
  if (fecha == null) {
    throw FormatException(
        'Puntos de recarga: ${donde()} con fecha que no es AAAA-MM-DD');
  }
  return FuenteCitada(
    nombre: _texto(crudo, 'nombre', donde),
    url: url,
    fecha: fecha,
  );
}

PuntoDeRecarga _leerPunto(
  Object? crudo,
  int indice,
  Map<String, FuenteCitada> fuentes,
) {
  if (crudo is! Map<String, Object?>) {
    throw FormatException(
        'Puntos de recarga: el punto $indice no es un objeto');
  }
  final idCrudo = crudo['id'];
  String donde() => 'el punto ${idCrudo is String ? idCrudo : indice}';

  final referencia = crudo['fuente'];
  final ejemplo = crudo['ejemplo'];
  final Fuente fuente;
  if (referencia != null && ejemplo != null) {
    throw FormatException(
        'Puntos de recarga: ${donde()} trae fuente y marca de ejemplo');
  } else if (referencia != null) {
    fuente = (referencia is String ? fuentes[referencia] : null) ??
        (throw FormatException(
            'Puntos de recarga: ${donde()} cita una fuente que no está '
            'en la lista ($referencia)'));
  } else if (ejemplo == true) {
    fuente = const FuenteEjemplo();
  } else {
    throw FormatException(
        'Puntos de recarga: ${donde()} no tiene fuente, y sin fuente la '
        'marca de ejemplo es obligatoria');
  }

  return PuntoDeRecarga(
    id: _texto(crudo, 'id', donde),
    nombre: _texto(crudo, 'nombre', donde),
    lat: _coordenada(crudo, 'lat', 90, donde),
    lon: _coordenada(crudo, 'lon', 180, donde),
    direccion: _texto(crudo, 'direccion', donde),
    municipio: _textoOpcional(crudo, 'municipio', donde),
    horario: _textoOpcional(crudo, 'horario', donde),
    fuente: fuente,
  );
}

String _texto(Map<String, Object?> m, String campo, String Function() donde) {
  final valor = m[campo];
  if (valor is String && valor.trim().isNotEmpty) return valor;
  throw FormatException(
      'Puntos de recarga: ${donde()} tiene $campo vacío o ausente');
}

String? _textoOpcional(
  Map<String, Object?> m,
  String campo,
  String Function() donde,
) =>
    m[campo] == null ? null : _texto(m, campo, donde);

double _coordenada(
  Map<String, Object?> m,
  String campo,
  double tope,
  String Function() donde,
) {
  final valor = m[campo];
  if (valor is num && valor.isFinite && valor.abs() <= tope) {
    return valor.toDouble();
  }
  throw FormatException(
      'Puntos de recarga: ${donde()} tiene $campo fuera de rango');
}
