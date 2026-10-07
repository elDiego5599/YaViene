// ¿Pasa esta ruta cerca de donde estoy?
//
// Faltaba la pregunta más básica antes de armar un aviso. La app validaba el
// bus —que tenga señal, que no esté ya encima— pero nunca el recorrido: si el
// usuario está en el norte y abre una ruta que va toda por el sur, el aviso se
// armaba igual y se quedaba esperando un bus que no iba a acercarse nunca. El
// usuario no ve un error, ve una notificación que no llega.
//
// Se mide contra la geometría de la ruta, no contra el bus: la posición del
// bus cambia cada segundo y la del recorrido no. Un bus que hoy está a 8 km
// puede estar a 500 m en veinte minutos si el recorrido pasa por aquí; si el
// recorrido no pasa, no hay minuto en que se acerque.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

import '../../../notifications/presentation/providers/distancia_aviso_provider.dart';
import '../utils/geo.dart';
import 'user_location_provider.dart';

/// Distancia en metros del punto del usuario al trozo más cercano del
/// recorrido, o **null cuando no se sabe**: sin ubicación, con la geometría
/// todavía cargando, o si la ruta no trae recorrido en `rutas.json`.
///
/// Null es "no se sabe", nunca "está lejos". Todo lo que consume esto falla
/// abierto: ante la duda se deja armar el aviso. Bloquear por un asset que
/// tardó en cargar sería peor que el problema que esto arregla.
final routeDistanceToUserProvider =
    Provider.autoDispose.family<double?, String>((ref, routeId) {
  final location = ref.watch(userLocationProvider);
  if (!location.hasPosition) return null;

  return distanciaDeRuta(ref.watch(routeTrajectoryProvider(routeId)).value,
      location.lat!, location.lon!);
});

/// Lo más que se acerca [trajectory] al punto ([lat], [lon]), o `null` si no
/// se sabe. «Cambiar» la mide desde el punto del aviso, que puede no ser el
/// de ahora.
double? distanciaDeRuta(RouteTrajectory? trajectory, double lat, double lon) {
  // `points` viene vacío cuando la ruta no está en rutas.json, y con un solo
  // punto no hay segmento que proyectar: en ambos casos projectOntoPolyline
  // devuelve 0 m, que se leería como "estás encima de la ruta".
  if (trajectory == null || trajectory.points.length < 2) return null;

  final projection =
      projectOntoPolyline(GeoPoint(lat: lat, lon: lon), trajectory.points);
  // Una polilínea de puntos repetidos no tiene ningún segmento con longitud:
  // la proyección sale infinita. Eso es no saber, no estar lejos.
  if (!projection.distanceMeters.isFinite) return null;
  return projection.distanceMeters;
}

/// True solo cuando se **sabe** que la ruta no pasa cerca: ni el aviso de
/// [distanciaAvisoMaxima] la alcanzaría. Sin ubicación o sin geometría es
/// false: no se bloquea nada por falta de datos.
///
/// Más cerca de eso hay aviso que sirve: la rueda empieza en lo más cerca
/// que pasa la ruta (`distanciaAvisoDesde`). La distancia guardada no
/// cuenta: antes, con 500 m guardados, una ruta a 800 m bloqueaba el botón
/// y no había rueda con la que elegir más (dueño, 2026-10-07).
///
/// Antes el tope valía 2 km, copiado del anillo verde que se dibuja
/// alrededor del pin. El anillo responde otra pregunta (qué buses ves) y
/// sigue en 2 km a propósito.
final routeTooFarFromUserProvider =
    Provider.autoDispose.family<bool, String>((ref, routeId) {
  final distance = ref.watch(routeDistanceToUserProvider(routeId));
  return distance != null && distance > distanciaAvisoMaxima;
});
