import 'dart:convert';

import 'package:flutter/services.dart';

/// Carga las fuentes de verdad del bundle. Sin esto las pruebas pintan con
/// Ahem, cuyas letras son cajas más anchas: las tarjetas miden más de lo
/// que miden en el teléfono y lo que se mide de su sitio no vale.
Future<void> cargarFuentes() async {
  final manifiesto = json.decode(
    await rootBundle.loadString('FontManifest.json'),
  ) as List<dynamic>;
  for (final entrada in manifiesto.cast<Map<String, dynamic>>()) {
    final cargador = FontLoader(entrada['family'] as String);
    for (final fuente
        in (entrada['fonts'] as List).cast<Map<String, dynamic>>()) {
      cargador.addFont(rootBundle.load(fuente['asset'] as String));
    }
    await cargador.load();
  }
}
