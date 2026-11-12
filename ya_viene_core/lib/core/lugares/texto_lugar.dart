/// Cómo se comparan lo que escribe el pasajero y los nombres del índice.
///
/// Las dos puntas pasan por [palabrasDe]: sin tildes, en minúscula y con la
/// nomenclatura de Barranquilla escrita entera, así «Cra 46», «Kr 46» y
/// «Carrera 46» son lo mismo y «Calle 72 # 46-20» se puede leer como una
/// dirección. Lo que no se reconoce se deja como vino: nada se adivina.
library;

/// Las abreviaturas de la nomenclatura urbana que se ven en Barranquilla,
/// en avisos, recibos y en lo que la gente escribe.
const _abreviaturas = {
  'cra': 'carrera',
  'cr': 'carrera',
  'crr': 'carrera',
  'carr': 'carrera',
  'kr': 'carrera',
  'kra': 'carrera',
  'cl': 'calle',
  'cll': 'calle',
  'cal': 'calle',
  'av': 'avenida',
  'avd': 'avenida',
  'avda': 'avenida',
  'dg': 'diagonal',
  'diag': 'diagonal',
  'tv': 'transversal',
  'tr': 'transversal',
  'trans': 'transversal',
  'transv': 'transversal',
};

/// Solas son ambiguas («Vitamina C»): solo valen delante de un número.
const _abreviaturasSueltas = {'c': 'calle', 'k': 'carrera'};

/// «No. 46», «N° 46», «Nro 46»: el numeral escrito con letras.
const _numerales = {'no', 'n', 'nro', 'num', 'numero'};

/// El separador de la placa en «Calle 72 # 46-20».
const numeral = '#';

const _tildes = {
  'á': 'a', 'à': 'a', 'ä': 'a', 'â': 'a', //
  'é': 'e', 'è': 'e', 'ë': 'e', 'ê': 'e', //
  'í': 'i', 'ì': 'i', 'ï': 'i', 'î': 'i', //
  'ó': 'o', 'ò': 'o', 'ö': 'o', 'ô': 'o', //
  'ú': 'u', 'ù': 'u', 'ü': 'u', 'û': 'u', //
  'ñ': 'n', 'ç': 'c',
};

final _separadores = RegExp(r'[^a-z0-9#]+');
final _viaPegada = RegExp(r'^([a-z]+)(\d.*)$');

/// Las palabras de la nomenclatura que alguien pega a su número: «Cl72»,
/// «Cra46B», «No46».
final _nomenclatura = {
  ..._abreviaturas.keys,
  ..._abreviaturas.values,
  ..._abreviaturasSueltas.keys,
  ..._numerales,
};
final _numero = RegExp(r'^\d+$');
final _numeroDeVia = RegExp(r'^\d+[a-z]*$');

/// Las palabras de [texto], listas para comparar.
///
/// La ñ se dobla a n como las tildes: quien escribe sin teclado en español
/// pone «Campina» y debe encontrar «La Campiña».
List<String> palabrasDe(String texto) {
  final plano = StringBuffer();
  for (final rune in texto.toLowerCase().runes) {
    final letra = String.fromCharCode(rune);
    plano.write(_tildes[letra] ?? letra);
  }
  final crudas = plano
      .toString()
      .replaceAll('#', ' # ')
      .split(_separadores)
      .where((p) => p.isNotEmpty)
      .expand(_despegar)
      .toList();

  final palabras = <String>[];
  for (var i = 0; i < crudas.length; i++) {
    final palabra = crudas[i];
    final siguienteEsNumero =
        i + 1 < crudas.length && _numero.hasMatch(crudas[i + 1]);
    final anteriorEsNumero =
        palabras.isNotEmpty && _numeroDeVia.hasMatch(palabras.last);

    if (_abreviaturas[palabra] case final entera?) {
      palabras.add(entera);
    } else if (siguienteEsNumero && _abreviaturasSueltas[palabra] != null) {
      palabras.add(_abreviaturasSueltas[palabra]!);
    } else if (siguienteEsNumero && _numerales.contains(palabra)) {
      palabras.add(numeral);
    } else if (anteriorEsNumero && _esSufijoDeVia(palabra)) {
      // «72 B» y «46 bis» son una sola vía: la 72B y la 46bis.
      palabras.last = palabras.last + palabra;
    } else {
      palabras.add(palabra);
    }
  }
  return palabras;
}

/// «cl72» son dos palabras, «calle» y «72»; «r111» se queda como vino.
Iterable<String> _despegar(String palabra) {
  final pegada = _viaPegada.firstMatch(palabra);
  if (pegada == null || !_nomenclatura.contains(pegada[1])) return [palabra];
  return [pegada[1]!, pegada[2]!];
}

/// La letra (a a h) o el «bis» que siguen al número de una vía. La «y»
/// no: en «72 y 46» une dos vías.
bool _esSufijoDeVia(String palabra) =>
    palabra == 'bis' ||
    (palabra.length == 1 &&
        palabra.codeUnitAt(0) >= 0x61 &&
        palabra.codeUnitAt(0) <= 0x68);

/// Si [escrita] es [nombre] con a lo sumo un error de una letra: una de
/// más, una de menos, una cambiada o dos vecinas volteadas.
///
/// Solo en palabras de cuatro letras o más y sin números: en «sol» contra
/// «col» o en «72» contra «73» una letra cambia el lugar entero.
bool casiIgual(String escrita, String nombre) {
  if (escrita == nombre) return true;
  if (escrita.length < 4 || nombre.length < 4) return false;
  if ((escrita.length - nombre.length).abs() > 1) return false;
  if (_tieneDigito(escrita) || _tieneDigito(nombre)) return false;
  return _distanciaDeEdicion(escrita, nombre) <= 1;
}

bool _tieneDigito(String s) {
  for (final c in s.codeUnits) {
    if (c >= 0x30 && c <= 0x39) return true;
  }
  return false;
}

/// Distancia de Damerau-Levenshtein restringida (cada letra se toca una
/// vez), que basta para contar un error.
int _distanciaDeEdicion(String a, String b) {
  final ancho = b.length + 1;
  var antes = List<int>.filled(ancho, 0);
  var previa = List<int>.generate(ancho, (j) => j);
  var actual = List<int>.filled(ancho, 0);
  for (var i = 1; i <= a.length; i++) {
    actual[0] = i;
    for (var j = 1; j <= b.length; j++) {
      final costo = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
      var d = previa[j] + 1;
      if (actual[j - 1] + 1 < d) d = actual[j - 1] + 1;
      if (previa[j - 1] + costo < d) d = previa[j - 1] + costo;
      if (i > 1 &&
          j > 1 &&
          a.codeUnitAt(i - 1) == b.codeUnitAt(j - 2) &&
          a.codeUnitAt(i - 2) == b.codeUnitAt(j - 1) &&
          antes[j - 2] + 1 < d) {
        d = antes[j - 2] + 1;
      }
      actual[j] = d;
    }
    final t = antes;
    antes = previa;
    previa = actual;
    actual = t;
  }
  return previa[b.length];
}
