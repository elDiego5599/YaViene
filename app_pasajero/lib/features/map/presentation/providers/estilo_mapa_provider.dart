import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

import 'estilo_guardado.dart';

/// El estilo que recibe MapLibre: el JSON de Voyager retocado como el del
/// panel ([estiloRetocado]), sin negocios que se confundan con los buses
/// (dueño, 2026-10-28). MapLibre no deja retocar un estilo que baja él
/// mismo de una dirección; por eso se baja aquí y se le entrega ya hecho, de
/// la copia guardada si la hay ([estiloDelMapa]).
///
/// Si no llega o no se entiende, va la dirección de Voyager tal cual: un
/// mapa sin retocar es mejor que una pantalla sin mapa.
final estiloMapaProvider = FutureProvider<String>((ref) async {
  return estiloDelMapa(
    prefs: await SharedPreferences.getInstance(),
    bajarVoyager: () async {
      final respuesta = await http
          .get(Uri.parse(kEstiloMapa))
          .timeout(const Duration(seconds: 10));
      return respuesta.statusCode == 200 ? respuesta.body : null;
    },
  );
});

/// La primera capa de rótulos (`symbol`) de [estilo] que va encima de todo
/// el dibujo del mapa, para meter la ruta debajo: así «Soledad» o
/// «BARRANQUILLA» se leen encima de la línea verde en vez de quedar tapados
/// (AUD29-37). Los rótulos que van entre capas dibujadas no cuentan:
/// Voyager pone `waterway_label` bajo calles y edificios, y la ruta metida
/// ahí quedaba tapada por todo el mapa. Con la dirección de Voyager (sin
/// red) o un JSON sin rótulos no hay capa que nombrar: la ruta va arriba.
String? primeraCapaDeRotulos(String estilo) {
  final Object? leido;
  try {
    leido = jsonDecode(estilo);
  } on FormatException {
    return null;
  }
  if (leido is! Map<String, dynamic>) return null;
  final capas = leido['layers'];
  if (capas is! List) return null;
  String? primera;
  for (final capa in capas) {
    if (capa is! Map) continue;
    if (capa['type'] != 'symbol') {
      primera = null;
    } else if (primera == null && capa['id'] is String) {
      primera = capa['id'] as String;
    }
  }
  return primera;
}
