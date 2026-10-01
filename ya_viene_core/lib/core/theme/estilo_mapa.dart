/// El estilo del mapa de las dos apps: Voyager de CARTO, mapa alegre y
/// colorido (agua azul, parques verdes, vías cálidas) como corresponde a
/// Barranquilla.
///
/// Vive aquí y no en cada app porque el pasajero y el panel tienen que ver
/// el mismo mapa (dueño, 2026-09-30): el operador que habla por teléfono
/// con alguien en el paradero describe la misma ciudad que ese alguien ve.
/// El pasajero lo pinta con MapLibre; el panel, que corre en escritorio,
/// con `vector_map_tiles` sobre las mismas teselas vectoriales.
const String kEstiloMapa =
    'https://basemaps.cartocdn.com/gl/voyager-gl-style/style.json';
