// Cómo se escribe una dirección en Barranquilla: «Cra 54 #72-80»,
// «Clle 72 #54-20» (dueño, 2026-11-15). Sin dependencias: es Dart puro para
// poder pasarla tal cual a `ya_viene_core` cuando otra pantalla la necesite.

const _vias = {
  'CLLE': 'Clle',
  'CLL': 'Clle',
  'CALLE': 'Clle',
  'CL': 'Clle',
  'CRA': 'Cra',
  'KRA': 'Cra',
  'KR': 'Cra',
  'CR': 'Cra',
  'CARRERA': 'Cra',
  'DIAG': 'Diag',
  'DIG': 'Diag',
  'DG': 'Diag',
  'DIAGONAL': 'Diag',
  'TRANSVERSAL': 'Trans',
  'TRANV': 'Trans',
  'TRANS': 'Trans',
  'TRAN': 'Trans',
  'TV': 'Trans',
  'VIA': 'Vía',
};

// La N de «número» como la escribe la fuente: N, No, No., N° o #.
final _marcaDeNumero = RegExp(r'^(?:N[°º]|NO\.?,?|N|#)$');

final _vocal = RegExp('[AEIOUÁÉÍÓÚ]');

// Prefijo, vía (66, 22SUR, 42B1, 66 C), número de la placa (15A, 15 A) y
// los dos del cierre. La N nunca cuenta como letra de la vía: «76 N 15» es
// la calle 76, no la 76N.
final _direccion = RegExp(
  r'^(?:(' // 1: prefijo de la vía, opcional
  r'CLLE|CLL|CALLE|CL|CRA|KRA|KR|CR|CARRERA|DIAGONAL|DIAG|DIG|DG|'
  r'TRANSVERSAL|TRANV|TRANS|TRAN|TV|VIA'
  r')\.?(?=\s|\d)\s*)?'
  r'(\d+\s?(?:[A-MO-RT-Z]\d*)?(?:\s?SUR)?)' // 2: la vía
  r'\s*(?:N[°º]|NO\.?,?|N|#)?\s*'
  r'(\d+(?:\s?[A-RT-Z]\d*)?(?:\s?SUR)?)' // 3: primera parte de la placa
  r'\s*-?\s*(\d+)' // 4: segunda parte
  r'(?=\s|$)(?:\s+(.*))?$', // 5: lo que sobre (LOC 3)
);

/// La dirección como se escribe aquí: «Cra 54 #72-80». Entiende lo que da la
/// fuente (CLL, CL, KR, N, No., N°, mayúsculas). Lo que no encaja en el
/// patrón queda legible: prefijos cambiados y el resto en minúsculas con su
/// inicial.
String direccionLegible(String fuente) {
  final texto = fuente.trim().toUpperCase().replaceAll(RegExp(r'\s+'), ' ');
  if (texto.isEmpty) return '';
  final m = _direccion.firstMatch(texto);
  if (m == null) return _palabras(texto);
  final via = m[2]!.replaceAll(' ', '').replaceFirst('SUR', ' Sur');
  final prefijo = m[1] == null ? '' : '${_vias[m[1]]} ';
  final placa = m[3]!.replaceAll(' ', '').replaceFirst('SUR', ' Sur');
  final resto = m[5] == null ? '' : ', ${_palabras(m[5]!)}';
  return '$prefijo$via #$placa-${m[4]}$resto';
}

/// Palabra por palabra: las vías con su abreviatura, la N de número como #,
/// lo que lleva dígitos se queda como viene y el resto toma inicial.
String _palabras(String texto) => [
      for (final palabra in texto.split(' '))
        if (_vias[palabra.replaceFirst(RegExp(r'\.$'), '')] case final via?)
          via
        else if (_marcaDeNumero.hasMatch(palabra))
          '#'
        else if (RegExp(r'\d').hasMatch(palabra) || !_vocal.hasMatch(palabra))
          palabra
        else
          palabra[0] + palabra.substring(1).toLowerCase(),
    ].join(' ');
