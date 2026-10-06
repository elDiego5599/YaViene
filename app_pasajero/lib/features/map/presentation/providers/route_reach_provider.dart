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

/// Lo más lejos que puede pasar un recorrido del punto del usuario para que
/// armar un aviso tenga sentido: exactamente la distancia a la que el aviso
/// suena, ni un metro más.
///
/// No admite margen, y esa es toda la regla: el aviso dispara cuando el bus
/// entra en esa distancia del punto de espera, así que si el recorrido
/// entero nunca entra, ningún bus de esa ruta va a entrar tampoco. El aviso
/// se quedaría armado para siempre.
///
/// La distancia es la que la persona guardó. Sin ninguna guardada todavía
/// puede elegir hasta [distanciaAvisoMaxima]: solo es lejos lo que ni ahí
/// sonaría.
///
/// Antes el tope valía 2 km, copiado del anillo verde que se dibuja alrededor
/// del pin, con la idea de dejar margen para caminar hacia la ruta. El margen
/// era falso —con el pin puesto a mano el aviso mide contra el pin, no contra
/// dónde camines— y el resultado era el peor posible: una ruta que pasa entre
/// 1 y 2 km dejaba armar el aviso de 1 km, el botón decía «AVISO ACTIVADO» y
/// no sonaba nunca. El anillo verde responde otra pregunta (qué buses ves) y
/// sigue en 2 km a propósito.
final distanciaMaximaDeRutaProvider = Provider<int>(
  (ref) => ref.watch(distanciaAvisoProvider) ?? distanciaAvisoMaxima,
);

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

  final trajectory = ref.watch(routeTrajectoryProvider(routeId)).value;
  // `points` viene vacío cuando la ruta no está en rutas.json, y con un solo
  // punto no hay segmento que proyectar: en ambos casos projectOntoPolyline
  // devuelve 0 m, que se leería como "estás encima de la ruta".
  if (trajectory == null || trajectory.points.length < 2) return null;

  final projection = projectOntoPolyline(
    GeoPoint(lat: location.lat!, lon: location.lon!),
    trajectory.points,
  );
  // Una polilínea de puntos repetidos no tiene ningún segmento con longitud:
  // la proyección sale infinita. Eso es no saber, no estar lejos.
  if (!projection.distanceMeters.isFinite) return null;
  return projection.distanceMeters;
});

/// True solo cuando se **sabe** que la ruta no pasa cerca. Sin ubicación o sin
/// geometría es false: no se bloquea nada por falta de datos.
final routeTooFarFromUserProvider =
    Provider.autoDispose.family<bool, String>((ref, routeId) {
  final distance = ref.watch(routeDistanceToUserProvider(routeId));
  return distance != null &&
      distance > ref.watch(distanciaMaximaDeRutaProvider);
});
