/// Una dirección como se escribe en Barranquilla (dueño, 2026-11-15):
/// «Cra 54 #72-80», «Clle 72 #54-20», «Dg 70 #12-5», «Tv 38 #4-10».
///
/// Lo que sale del índice de calles, de lo guardado o de otra fuente llega
/// como «Carrera 54 # 72-80», «Cl. 72 No. 54-20» o «Kr 54 N° 72-80»; todo
/// lo que el buscador y el planificador muestran pasa por aquí para que se
/// lea igual en todas partes. Lo que no es nomenclatura (un barrio, un
/// sitio, «Avenida Circunvalar», «La Calle Real») se queda como vino: la vía
/// solo se reconoce delante de su número.
String direccionCorta(String texto) => texto
    .replaceAllMapped(_via, (m) => '${_canonica(m[1]!)} ')
    .replaceAll(_numeral, ' #')
    .replaceAllMapped(_letra, (m) => '${m[1]}${_sufijo(m[2]!)}')
    .replaceAllMapped(_placa, (m) => '${m[1]}-${m[2]}')
    .replaceAll(_espacios, ' ')
    .trim();

/// La vía y su abreviatura, pegada o no al número, con o sin punto. La c y
/// la k solas no cuentan tras un número: ahí son la letra de la vía
/// («Calle 72 C»), no otra calle.
final _via = RegExp(
  r'(?<![\p{L}\d])'
  r'(transversal|transv|trans|tv|tr|diagonal|diag|dg|carrera|carr|crr|cra|'
  r'cr|kra|kr|calle|clle|cll|cl|(?<!\d\s*)[ck])'
  r'\.?\s*(?=\d)',
  caseSensitive: false,
  unicode: true,
);

/// El numeral en todas sus formas («#», «N°», «Nº», «No.», «Nro», «Num»,
/// «Número»), con o sin espacios alrededor, siempre delante de un número.
final _numeral = RegExp(
  r'\s*(?<!\p{L})(?:#|n[°º]|n[uú]mero|nro\.?|num\.?|no\.?)\s*(?=\d)',
  caseSensitive: false,
  unicode: true,
);

/// La letra o el bis del número de una vía o de una placa, suelto o pegado:
/// «72 B», «46b», «46 Bis». Solo tras la vía ya corta o el numeral, para no
/// tocar «Vía 40 a Soledad».
final _letra = RegExp(
  r'((?:\b(?:Clle|Cra|Dg|Tv) |#)\d+)\s*(bis|[a-h])(?!\p{L})',
  caseSensitive: false,
  unicode: true,
);

/// El guion de la placa sin espacios: «72 - 80» es «72-80».
final _placa = RegExp(r'(\d[A-Za-z]*)\s*-\s*(\d)');

final _espacios = RegExp(r'\s+');

String _canonica(String via) => switch (via.toLowerCase()) {
      'transversal' || 'transv' || 'trans' || 'tv' || 'tr' => 'Tv',
      'diagonal' || 'diag' || 'dg' => 'Dg',
      'calle' || 'clle' || 'cll' || 'cl' || 'c' => 'Clle',
      _ => 'Cra',
    };

String _sufijo(String sufijo) =>
    sufijo.length == 1 ? sufijo.toUpperCase() : 'Bis';
