// El pintor del panel (vector_tile_renderer 6.1) se quedó en la sintaxis
// vieja de los estilos: no entiende `["in", ["get", k], ["literal", [...]]]`
// ni `["zoom"]` fuera de una interpolación. Voyager ya trae los dos en los
// filtros de calles, ríos y barrios, y el pintor deja esas capas vacías: las
// calles chicas del panel nunca salían (dueño, 2026-10-28). El pasajero pinta
// con MapLibre, que sí los entiende, y no pasa por aquí.

/// El estilo con sus expresiones en la forma que entiende el pintor del
/// panel. Dicen lo mismo: solo cambia cómo se escriben. No toca [estilo].
Map<String, dynamic> estiloParaPintor(Map<String, dynamic> estilo) =>
    _traducir(estilo) as Map<String, dynamic>;

Object? _traducir(Object? valor) {
  if (valor is Map) {
    return <String, dynamic>{
      for (final MapEntry(:key, :value) in valor.entries)
        key as String: _traducir(value),
    };
  }
  if (valor is! List) return valor;
  // `["zoom"]` suelto: el pintor lo lee como la propiedad `zoom`, que su
  // contexto resuelve con el zoom de la tesela.
  if (valor.length == 1 && valor.first == 'zoom') return ['get', 'zoom'];
  // `["in", ["get", k], ["literal", [a, b]]]` es `["in", k, a, b]`.
  if (valor case [
    'in',
    ['get', final String propiedad],
    ['literal', final List opciones],
  ]) {
    return ['in', propiedad, ...opciones];
  }
  return [for (final parte in valor) _traducir(parte)];
}
