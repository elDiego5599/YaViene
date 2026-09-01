import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// El candado del sistema de diseño.
///
/// La Fase 2 define la escala; sin esto, la Fase 3 migraría un archivo
/// mientras alguien —yo, dentro de dos semanas— añade tres `TextStyle`
/// sueltos en otro, y el trabajo no terminaría nunca.
///
/// No prohíbe lo que ya existe: cuenta. Si el número sube, falla. Si baja,
/// falla también y pide que se baje el techo, para que lo ganado quede
/// cerrado. Es un trinquete, no una muralla.
///
/// Se mide sobre `lib/`, sin comentarios ni cadenas, porque un ejemplo
/// dentro de un comentario no lo pinta nadie.
void main() {
  test('el techo de estilos sueltos no sube', () {
    final medida = _medir();
    expect(
      medida.tamanosSueltos,
      _techoTamanos,
      reason: _porQue(
        'un `TextStyle(` con `fontSize:` a mano',
        medida.tamanosSueltos,
        _techoTamanos,
        'AppTextStyles.dato / display / titulo / subtitulo / cuerpoFuerte / '
            'cuerpo / etiqueta / pie',
      ),
    );
  });

  test('no queda ningún radio suelto', () {
    final medida = _medir();
    expect(
      medida.radiosSueltos,
      isZero,
      reason: 'Apareció un `circular(` con un número a mano. Los radios ya '
          'están todos migrados: este contador llegó a cero y se quedó ahí.\n'
          'Usa AppRadius.sm / md / lg / card / sheet / pill. Si de verdad hace '
          'falta un radio que no está, el que falta es una constante nueva en '
          '`app_theme.dart`, no una excepción aquí.',
    );
  });
}

// El techo que queda. Bajó con cada archivo que migró la Fase 3, de 77 a uno.
// El que sobrevive es el numeral del tour (`map_tour_overlay.dart`): una
// miniatura del rol `dato`, escrita a mano porque un solo sitio no basta para
// abrir un rol. Los radios ya llegaron a cero y su prueba es `isZero`; si este
// llegara a cero también, esta línea desaparece y la de arriba se le parece.
const int _techoTamanos = 1;

String _porQue(String loSuelto, int hay, int techo, String enSuLugar) {
  if (hay > techo) {
    return 'Había $techo sitios con $loSuelto y ahora hay $hay.\n'
        'Usa uno de los roles de la escala: $enSuLugar.\n'
        'Si de verdad hace falta un valor que no está, el que falta es un '
        'rol nuevo en `app_theme.dart`, no una excepción aquí.';
  }
  return 'Quedan $hay sitios con $loSuelto y el techo estaba en $techo: '
      'migraste ${techo - hay} y no bajaste el techo.\n'
      'Baja `_techo…` a $hay en este archivo, en el mismo commit, para que '
      'lo ganado no se pueda volver a perder.';
}

class _Medida {
  const _Medida(this.tamanosSueltos, this.radiosSueltos);
  final int tamanosSueltos;
  final int radiosSueltos;
}

_Medida _medir() {
  var tamanos = 0;
  var radios = 0;
  for (final archivo in Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))) {
    final codigo = _sinComentariosNiCadenas(archivo.readAsStringSync());
    tamanos += _fontSizeLiteral.allMatches(codigo).length;
    radios += _circularLiteral.allMatches(codigo).length;
  }
  return _Medida(tamanos, radios);
}

final RegExp _fontSizeLiteral = RegExp(r'fontSize:\s*-?\d');
final RegExp _circularLiteral = RegExp(r'circular\(\s*-?\d');

/// Deja el código sin comentarios ni literales de texto.
///
/// Un `fontSize: 14` citado en un comentario que explica por qué ya no se
/// usa no es una violación; contarlo haría que documentar saliera caro.
String _sinComentariosNiCadenas(String fuente) {
  final salida = StringBuffer();
  var i = 0;
  while (i < fuente.length) {
    final resto = fuente.substring(i);
    if (resto.startsWith('//')) {
      final fin = fuente.indexOf('\n', i);
      i = fin == -1 ? fuente.length : fin;
      continue;
    }
    if (resto.startsWith('/*')) {
      final fin = fuente.indexOf('*/', i);
      i = fin == -1 ? fuente.length : fin + 2;
      continue;
    }
    final comilla = fuente[i];
    if (comilla == "'" || comilla == '"') {
      i++;
      while (i < fuente.length && fuente[i] != comilla) {
        i += fuente[i] == r'\' ? 2 : 1;
      }
      i++;
      continue;
    }
    salida.write(fuente[i]);
    i++;
  }
  return salida.toString();
}
