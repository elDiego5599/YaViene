import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Si el teléfono tiene alguna red (wifi, datos, cable).
///
/// El socket tarda en enterarse de que se cayó el wifi —espera a que falle
/// su latido— y una carga sin red falla igual que una con el servidor
/// caído. El sistema lo sabe al instante: con esto la app dice «Sin
/// internet» en vez de culpar al servidor, y vuelve a pedir lo que falló en
/// cuanto la red regresa (dueño, 2026-09-30).
///
/// `true` no promete salida a internet (un wifi de portal cautivo también
/// cuenta como red); `false` sí asegura que no la hay.
final hayRedProvider = StreamProvider<bool>((ref) async* {
  final conectividad = Connectivity();
  try {
    yield _hayRed(await conectividad.checkConnectivity());
  } on MissingPluginException {
    // Sin el plugin (pruebas de widgets) no hay a quién preguntar: se da
    // la red por buena y no se escucha el canal de eventos, que sin nadie
    // al otro lado reporta un error por cada suscripción.
    yield true;
    return;
  } on PlatformException {
    yield true;
    return;
  }
  yield* conectividad.onConnectivityChanged.map(_hayRed);
});

bool _hayRed(List<ConnectivityResult> redes) =>
    redes.any((r) => r != ConnectivityResult.none);
