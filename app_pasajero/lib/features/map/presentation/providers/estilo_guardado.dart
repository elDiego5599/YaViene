import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

/// Dónde se guarda el último Voyager que llegó, crudo: el retoque se aplica
/// al leerlo, así un retoque nuevo de la app no espera a la red.
const claveVoyagerGuardado = 'mapa.voyager';

/// El estilo del mapa, sin esperar a la red si ya hay copia (dueño,
/// 2026-11-03, «carga muy lento»): MapLibre no se crea hasta tener estilo, y
/// bajarlo en cada arranque dejaba la pantalla en «Preparando tu mapa» lo
/// que tardara CARTO, hasta 10 s con mala señal.
///
/// Con copia, sale de ella y lo que baje [bajarVoyager] la refresca para el
/// próximo arranque. Sin copia, espera a la red. Una respuesta que no es un
/// estilo no pisa la copia; sin copia ni red, la dirección de Voyager.
Future<String> estiloDelMapa({
  required SharedPreferences prefs,
  required Future<String?> Function() bajarVoyager,
}) async {
  final fresco = _bajarYGuardar(prefs, bajarVoyager);
  final guardado = _retocar(prefs.getString(claveVoyagerGuardado));
  if (guardado != null) {
    unawaited(fresco);
    return guardado;
  }
  return await fresco ?? kEstiloMapa;
}

Future<String?> _bajarYGuardar(
  SharedPreferences prefs,
  Future<String?> Function() bajarVoyager,
) async {
  final String? cuerpo;
  try {
    cuerpo = await bajarVoyager();
  } on Exception {
    return null;
  }
  final estilo = _retocar(cuerpo);
  if (estilo != null) await prefs.setString(claveVoyagerGuardado, cuerpo!);
  return estilo;
}

String? _retocar(String? cuerpo) {
  if (cuerpo == null) return null;
  try {
    final voyager = jsonDecode(cuerpo);
    // Un portal cautivo o un error de CARTO también llegan como JSON.
    if (voyager is! Map<String, dynamic> || voyager['layers'] is! List) {
      return null;
    }
    return jsonEncode(estiloRetocado(voyager));
  } on FormatException {
    return null;
  }
}
