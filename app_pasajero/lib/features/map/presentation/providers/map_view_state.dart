import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

final mapBottomInsetProvider = StateProvider.autoDispose<double>((ref) => 0);

/// El selector de ruta está arriba, ocupando la pantalla.
///
/// Se apoya en el mismo borde inferior que la hoja de distancia, así que
/// mientras esté abierto la hoja se aparta: si no, asoma por debajo del
/// selector como un segundo borde redondeado, y al arrastrar el selector
/// hacia abajo aparecía otra tarjeta detrás en vez del mapa. Vuelve sola al
/// cerrarse el selector —también, y sobre todo, cuando no se eligió ruta.
final routeSelectorOpenProvider =
    StateProvider.autoDispose<bool>((ref) => false);

/// F7: si la superposición "Preparando tu mapa…" sigue visible, el resto de
/// la pantalla no debe amontonar sus propios indicadores de carga (ubicación,
/// conexión) encima — un solo estado coordinado en vez de tres sueltos.
final mapPreparingProvider = StateProvider.autoDispose<bool>((ref) => true);

/// Intención de cámara para el mapa (p. ej. centrar la ciudad al reiniciar la
/// guía de uso). Se cuenta por solicitud: cada llamada incrementa el contador
/// y el mapa reaplica la última petición aunque no haya cambiado la posición.
class MapCameraRequestNotifier extends StateNotifier<int> {
  MapCameraRequestNotifier() : super(0);

  static const barranquilla = LatLng(11.0041, -74.8070);

  void centerOnBarranquilla() => state++;
}

/// Petición de volver al punto de espera, desde el botón de recentrar del
/// mapa. Mismo mecanismo que [MapCameraRequestNotifier]: se cuenta por
/// solicitud, porque tocar el botón dos veces seguidas —después de arrastrar
/// el mapa en medio— tiene que mover la cámara las dos veces.
class MapRecenterRequestNotifier extends StateNotifier<int> {
  MapRecenterRequestNotifier() : super(0);

  void recenter() => state++;
}

final mapRecenterRequestProvider =
    StateNotifierProvider<MapRecenterRequestNotifier, int>(
        (ref) => MapRecenterRequestNotifier());

final mapCameraRequestProvider =
    StateNotifierProvider<MapCameraRequestNotifier, int>(
        (ref) => MapCameraRequestNotifier());
