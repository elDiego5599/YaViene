import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

final mapBottomInsetProvider = StateProvider.autoDispose<double>((ref) => 0);

/// Intención de cámara para el mapa (p. ej. centrar la ciudad al reiniciar la
/// guía de uso). Se cuenta por solicitud: cada llamada incrementa el contador
/// y el mapa reaplica la última petición aunque no haya cambiado la posición.
class MapCameraRequestNotifier extends StateNotifier<int> {
  MapCameraRequestNotifier() : super(0);

  static const barranquilla = LatLng(11.0041, -74.8070);

  void centerOnBarranquilla() => state++;
}

final mapCameraRequestProvider =
    StateNotifierProvider<MapCameraRequestNotifier, int>(
        (ref) => MapCameraRequestNotifier());
