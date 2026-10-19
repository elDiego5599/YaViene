import 'package:flutter/painting.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

import 'bus_labels.dart';

/// El color de cada ruta, por su código: va en su ficha, en su trazo del
/// mapa, en su bus y en su fila del selector, para que la ruta se reconozca
/// sin leerla, como las líneas en Transit (dueño, 2026-10-19).
///
/// Ninguno es rojo, naranja ni ámbar: en la app el coral dice «sin
/// conexión» y el ámbar «cuidado». Todos llevan la letra blanca de la ficha
/// a 5:1 o más y se separan del fondo de Voyager (#F2EFE9) a 4:1 o más
/// (`test/color_ruta_test.dart`; para un trazo bastan 3:1).
const Map<String, Color> coloresRuta = {
  'B18': AppColors.acento, // azul de botón, 7,1:1: el de su ficha de siempre
  'C11': Color(0xFF047857), // esmeralda, 5,5:1
  'C12': Color(0xFF7E22CE), // violeta, 7,0:1
  'C13': Color(0xFF0F766E), // petróleo, 5,5:1
  'C14': Color(0xFFBE185D), // frambuesa, 6,0:1
  'C16': Color(0xFF4338CA), // índigo, 7,9:1
  'A1': Color(0xFF0E7490), // cian, 5,4:1
  'A3': Color(0xFFA21CAF), // fucsia, 6,3:1
  'A4': Color(0xFF4D7C0F), // oliva, 5,0:1
};

/// El color de la ruta llamada [routeName]. Una sin código, o con uno que
/// aún no está en [coloresRuta], va en el azul de botón.
Color colorRuta(String? routeName) =>
    coloresRuta[codigoRuta(routeName)] ?? AppColors.acento;

/// [color] en el `#RRGGBB` que pide MapLibre.
String hexDe(Color color) {
  final rgb = color.toARGB32() & 0xFFFFFF;
  return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
}

/// El fondo de la insignia de la ruta en el selector: su color muy
/// aclarado, con el código encima en el color entero (a 4,5:1 o más,
/// `test/color_ruta_test.dart`). Es el tinte verde de antes, por ruta.
Color tinteRuta(Color color) =>
    Color.lerp(color, const Color(0xFFFFFFFF), 0.93)!;
