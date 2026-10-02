import 'dart:ui' show Rect;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import '../utils/map_constants.dart';

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

/// Alguien fuera de la píldora pide abrir el selector de ruta: cada pedido
/// sube el número. Lo abre la píldora, que es la dueña del selector y de sus
/// guías; así no hay dos maneras de abrirlo. Lo pide «Escoge empresa y
/// ruta» en la hoja (dueño, 2026-09-28: la gente tocaba ahí).
final pedirSelectorProvider = StateProvider.autoDispose<int>((ref) => 0);

/// F7: si la superposición "Preparando tu mapa…" sigue visible, el resto de
/// la pantalla no debe amontonar sus propios indicadores de carga (ubicación,
/// conexión) encima — un solo estado coordinado en vez de tres sueltos.
final mapPreparingProvider = StateProvider.autoDispose<bool>((ref) => true);

/// Intención de cámara para el mapa (p. ej. centrar la ciudad al reiniciar la
/// guía de uso). Se cuenta por solicitud: cada llamada incrementa el contador
/// y el mapa reaplica la última petición aunque no haya cambiado la posición.
class MapCameraRequestNotifier extends StateNotifier<int> {
  MapCameraRequestNotifier() : super(0);

  /// El centro del área servida, no el centro geográfico de la ciudad: la
  /// cámara general tiene que dejar ver de Malambo al norte de Barranquilla,
  /// y con el punto en el norte la mitad del encuadre caía en el mar.
  static const barranquilla = LatLng(
    MapConstants.areaCentroLat,
    MapConstants.areaCentroLon,
  );

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

/// El trozo del mapa que la guía deja a la vista, cuando lo que hay que
/// mirar es el mapa mismo (el paso de los buses). Mientras está puesto, la
/// cámara encuadra el punto de espera en el centro de ese trozo y no en el
/// hueco entre la barra y la hoja: la tarjeta de la guía va encima del área
/// y el pin centrado a la manera de siempre quedaba debajo de ella.
final mapGuideFocusProvider = StateProvider<Rect?>((ref) => null);

final mapRecenterRequestProvider =
    StateNotifierProvider<MapRecenterRequestNotifier, int>(
        (ref) => MapRecenterRequestNotifier());

final mapCameraRequestProvider =
    StateNotifierProvider<MapCameraRequestNotifier, int>(
        (ref) => MapCameraRequestNotifier());

/// Un bus al que la cámara tiene que ir en cuanto aparezca en el mapa: el
/// del aviso que se acaba de tocar. Sus posiciones llegan un rato después de
/// escoger la ruta, así que el pedido espera aquí hasta que el mapa lo ve.
/// Si entretanto la persona cambia de ruta, se olvida: no hay que saltar a
/// un bus de una ruta que ya no está mirando.
class EnfoqueDeBus extends Notifier<({String busId, String routeId})?> {
  @override
  ({String busId, String routeId})? build() {
    ref.listen<RouteInfo?>(selectedRouteProvider, (_, ruta) {
      if (state != null && ruta?.id != state!.routeId) state = null;
    });
    return null;
  }

  void pedir(String busId, String routeId) =>
      state = (busId: busId, routeId: routeId);

  void hecho() => state = null;
}

final enfoqueDeBusProvider =
    NotifierProvider<EnfoqueDeBus, ({String busId, String routeId})?>(
        EnfoqueDeBus.new);
