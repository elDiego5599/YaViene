import 'package:flutter/widgets.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart';

/// Voyager de CARTO en vectores, retocado para el panel: la capa de fondo de
/// los dos mapas, el de la flota y el de Reportes.
///
/// `vector_map_tiles` guarda en disco las teselas que baja y las que pinta,
/// con un tope de 50 MB por defecto. Solo la ciudad pintada a zoom 15 ya
/// ocupa unos 50 MB (237 KB cada una, medido el 2026-11-03), así que el panel
/// borraba lo que había pintado y lo volvía a bajar y a pintar al moverse
/// (dueño, 2026-11-03, «carga muy lento»). Con 256 MB caben Barranquilla y
/// Soledad de zoom 12 a 16 (unos 180 MB) y las teselas crudas, con holgura
/// para las de un retoque anterior hasta que se borren por viejas.
///
/// Las teselas de CARTO son de 512 px, como las de Mapbox, y el estilo cuenta
/// sus zooms así. Con el desfase de fábrica (teselas de 256) el panel pintaba
/// cada vista con el estilo de un zoom más cerca que el pasajero: calles gordas
/// y apretadas de lejos (dueño, 2026-11-03, «toca acercarme mucho para que se
/// vea bien»). `TileOffset.mapbox` lo deja como MapLibre.
class CapaVoyager extends StatelessWidget {
  const CapaVoyager({super.key, required this.estilo});

  static const tamanoCacheDisco = 256 * 1024 * 1024;

  final Style estilo;

  @override
  Widget build(BuildContext context) => VectorTileLayer(
    theme: estilo.theme,
    sprites: estilo.sprites,
    tileProviders: estilo.providers,
    fileCacheMaximumSizeInBytes: tamanoCacheDisco,
    tileOffset: TileOffset.mapbox,
  );
}
