import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:ya_viene_core/ya_viene_core.dart';

/// El estilo que recibe MapLibre: el JSON de Voyager retocado como el del
/// panel ([estiloRetocado]), sin negocios que se confundan con los buses
/// (dueño, 2026-10-28). MapLibre no deja retocar un estilo que baja él
/// mismo de una dirección; por eso se baja aquí y se le entrega ya hecho.
///
/// Si no llega o no se entiende, va la dirección de Voyager tal cual: un
/// mapa sin retocar es mejor que una pantalla sin mapa.
final estiloMapaProvider = FutureProvider<String>((ref) async {
  try {
    final respuesta = await http
        .get(Uri.parse(kEstiloMapa))
        .timeout(const Duration(seconds: 10));
    if (respuesta.statusCode != 200) return kEstiloMapa;
    final voyager = jsonDecode(respuesta.body);
    if (voyager is! Map<String, dynamic>) return kEstiloMapa;
    return jsonEncode(estiloRetocado(voyager));
  } on Exception {
    return kEstiloMapa;
  }
});
