// «Estoy aquí, voy allá»: qué ruta tomar, dónde subir y dónde bajar
// (docs/viaje-completo.md, sección 3.3). Geometría pura, sin red ni reloj.
import 'dart:math' as math;

import '../geo/distancia.dart';
import '../geo/por_ruta.dart';
import '../lugares/lugar.dart';
import 'red_de_rutas.dart';
import 'viaje.dart';

/// Los topes de una búsqueda.
class OpcionesDePlan {
  const OpcionesDePlan({
    this.caminataMaxima = 600,
    this.conTransbordo = true,
    this.maximo = 3,
    this.tramoMinimo = 300,
  });

  /// Lo más que se camina de una vez, en línea recta: del origen a la
  /// subida o de la bajada al destino. 600 m son unos 8 minutos.
  final double caminataMaxima;

  /// Si se ofrecen viajes con un cambio de bus. Más de uno no se ofrece.
  final bool conTransbordo;

  /// Cuántos viajes se devuelven, del mejor al peor.
  final int maximo;

  /// Lo menos que vale la pena andar en un bus: por menos se camina.
  final double tramoMinimo;
}

/// Lo que responde [planear].
sealed class Plan {
  const Plan();
}

/// Hay por dónde ir: [viajes], del mejor al peor, nunca vacía.
final class PlanConViajes extends Plan {
  const PlanConViajes(this.viajes);
  final List<Viaje> viajes;
}

/// Los dos puntos están a [metros] en línea recta y ningún bus ahorra
/// caminata: se llega antes a pie.
final class PlanMuyCerca extends Plan {
  const PlanMuyCerca(this.metros);
  final double metros;
}

/// Ninguna ruta lleva de un punto al otro. Lo que sí se sabe sirve para
/// decirle a la persona qué punto mover.
final class PlanSinRuta extends Plan {
  const PlanSinRuta({
    required this.pasaCercaDelOrigen,
    required this.pasaCercaDelDestino,
  });

  /// Alguna ruta pasa a menos de la caminata máxima del origen.
  final bool pasaCercaDelOrigen;

  /// Alguna ruta pasa a menos de la caminata máxima del destino.
  final bool pasaCercaDelDestino;
}

/// Por debajo de esto ni se busca bus: 400 m son cinco minutos a pie, menos
/// de lo que se espera uno.
const double _muyCerca = 400;

/// Lo que cuesta un viaje se cuenta en metros de bus, y un metro a pie
/// pesa lo que cuatro en bus (1,3 m/s caminando contra unos 5 m/s de un
/// bus urbano con sus paradas). Con eso se escoge dónde subir y dónde
/// bajar y se ordenan las opciones. Sin el peso ganaba siempre el punto
/// más cercano: en una calle de ida y vuelta, subirse al carril contrario
/// y darle la vuelta a la ruta por ahorrarse cruzar la calle; y entre la
/// Terminal y el Zoológico iba primero la ruta que anda 12 km más por
/// caminar 100 m menos.
const double _pesoDeLaCaminata = 4;

double _costo(Viaje viaje) =>
    _pesoDeLaCaminata * viaje.caminataTotal + viaje.metrosEnBus;

/// Un viaje que cuesta más de esto por el mejor no es una alternativa:
/// de la Universidad del Atlántico al Country, la ruta que anda 9,5 km
/// al lado de la que llega en 3,4.
const double _peorQueSeOfrece = 2;

/// Las 15 rutas son vueltas de 23 a 60 km: casi cualquier par de puntos
/// de una ruta se une «en el sentido de la ruta», aunque sea dándole la
/// vuelta entera. Un viaje así no se ofrece: en bus se anda, como mucho,
/// tres veces la línea recta más 2 km (lo que una ruta puede torcerse en
/// un viaje corto).
double _rodeoMaximo(double recta) => 3 * recta + 2000;

/// Un segundo bus es otra espera y otro pasaje: solo se ofrece si ahorra
/// al menos esto a pie (cinco minutos) frente al mejor viaje de un bus.
/// Con 200 m salían cambios de 400 m en bus por caminar 250 menos.
const double _ahorroDeUnCambio = 400;

/// Las maneras de ir de [origen] a [destino] por las rutas de [red].
///
/// Primero los viajes de un bus y luego los de dos; entre iguales, el que
/// menos cuesta, con la caminata pesando cuatro veces. Por cada ruta (o
/// par de rutas) sale un solo viaje, el de sus mejores puntos de subida y
/// bajada.
Plan planear(
  Lugar origen,
  Lugar destino,
  RedDeRutas red, [
  OpcionesDePlan opciones = const OpcionesDePlan(),
]) {
  final recta = haversineMeters(
      origen.punto.lat, origen.punto.lon, destino.punto.lat, destino.punto.lon);
  if (recta < _muyCerca) return PlanMuyCerca(recta);

  final rutas = red.rutas;
  final subidas = [
    for (final ruta in rutas)
      ruta.medible.pasosCerca(origen.punto, opciones.caminataMaxima),
  ];
  final bajadas = [
    for (final ruta in rutas)
      ruta.medible.pasosCerca(destino.punto, opciones.caminataMaxima),
  ];

  final viajes = <Viaje>[
    for (var r = 0; r < rutas.length; r++)
      if (_directo(origen, destino, rutas[r], subidas[r], bajadas[r], opciones)
          case final viaje?)
        viaje,
    if (opciones.conTransbordo)
      for (var de = 0; de < rutas.length; de++)
        if (subidas[de].isNotEmpty)
          for (var a = 0; a < rutas.length; a++)
            if (a != de && bajadas[a].isNotEmpty)
              if (_conCambio(origen, destino, rutas[de], rutas[a],
                      red.cambios(de, a), subidas[de], bajadas[a], opciones)
                  case final viaje?)
                viaje,
  ]..removeWhere((viaje) =>
      // El bus ahorra caminata o no se ofrece.
      viaje.caminataTotal >= recta || viaje.metrosEnBus > _rodeoMaximo(recta));

  final mejorDeUnBus = [
    for (final viaje in viajes)
      if (viaje.buses == 1) viaje.caminataTotal,
  ].fold(double.infinity, (a, b) => a < b ? a : b);
  viajes.removeWhere((viaje) =>
      viaje.buses > 1 &&
      viaje.caminataTotal > mejorDeUnBus - _ahorroDeUnCambio);

  if (viajes.isEmpty) {
    if (recta <= opciones.caminataMaxima) return PlanMuyCerca(recta);
    return PlanSinRuta(
      pasaCercaDelOrigen: subidas.any((pasos) => pasos.isNotEmpty),
      pasaCercaDelDestino: bajadas.any((pasos) => pasos.isNotEmpty),
    );
  }
  final tope = _peorQueSeOfrece * viajes.map(_costo).reduce(math.min);
  viajes
    ..removeWhere((viaje) => _costo(viaje) > tope)
    ..sort(_delMejorAlPeor);
  return PlanConViajes(viajes.take(opciones.maximo).toList());
}

int _delMejorAlPeor(Viaje a, Viaje b) {
  final buses = a.buses.compareTo(b.buses);
  return buses != 0 ? buses : _costo(a).compareTo(_costo(b));
}

/// El mejor viaje por [ruta] sola, o null si no lleva: de cada paso cerca
/// del origen a cada paso cerca del destino, el par que menos cuesta.
Viaje? _directo(
  Lugar origen,
  Lugar destino,
  RutaDeLaRed ruta,
  List<Proyeccion> subidas,
  List<Proyeccion> bajadas,
  OpcionesDePlan opciones,
) {
  Viaje? mejor;
  var menor = double.infinity;
  for (final sube in subidas) {
    for (final baja in bajadas) {
      final enBus = ruta.medible.recorridoDirigido(sube.avance, baja.avance);
      if (enBus == null || enBus < opciones.tramoMinimo) continue;
      final costo = _pesoDeLaCaminata * (sube.desvio + baja.desvio) + enBus;
      if (costo >= menor) continue;
      menor = costo;
      final subida = _punto(ruta, sube.avance, sube.desvio);
      final bajada = _punto(ruta, baja.avance, baja.desvio);
      mejor = Viaje(origen: origen, destino: destino, tramos: [
        TramoAPie(
            desde: origen.punto, hasta: subida.punto, metros: sube.desvio),
        _enBus(ruta, subida, bajada, enBus),
        TramoAPie(
            desde: bajada.punto, hasta: destino.punto, metros: baja.desvio),
      ]);
    }
  }
  return mejor;
}

/// El mejor viaje que sube a [primera] cerca del origen, cambia a
/// [segunda] en uno de los [cambios] y baja cerca del destino; null si
/// ninguno sirve.
Viaje? _conCambio(
  Lugar origen,
  Lugar destino,
  RutaDeLaRed primera,
  RutaDeLaRed segunda,
  List<Cambio> cambios,
  List<Proyeccion> subidas,
  List<Proyeccion> bajadas,
  OpcionesDePlan opciones,
) {
  ({
    Proyeccion sube,
    Cambio cambio,
    Proyeccion baja,
    double a,
    double b
  })? mejor;
  var menor = double.infinity;
  for (final cambio in cambios) {
    for (final sube in subidas) {
      final enPrimera =
          primera.medible.recorridoDirigido(sube.avance, cambio.baja);
      if (enPrimera == null || enPrimera < opciones.tramoMinimo) continue;
      for (final baja in bajadas) {
        final enSegunda =
            segunda.medible.recorridoDirigido(cambio.sube, baja.avance);
        if (enSegunda == null || enSegunda < opciones.tramoMinimo) continue;
        final costo =
            _pesoDeLaCaminata * (sube.desvio + cambio.caminata + baja.desvio) +
                enPrimera +
                enSegunda;
        if (costo >= menor) continue;
        menor = costo;
        mejor = (
          sube: sube,
          cambio: cambio,
          baja: baja,
          a: enPrimera,
          b: enSegunda
        );
      }
    }
  }
  if (mejor == null) return null;
  final (:sube, :cambio, :baja, :a, :b) = mejor;
  final subida = _punto(primera, sube.avance, sube.desvio);
  final bajaDeLaPrimera = _punto(primera, cambio.baja, cambio.caminata);
  final subeALaSegunda = _punto(segunda, cambio.sube, cambio.caminata);
  final bajada = _punto(segunda, baja.avance, baja.desvio);
  return Viaje(origen: origen, destino: destino, tramos: [
    TramoAPie(desde: origen.punto, hasta: subida.punto, metros: sube.desvio),
    _enBus(primera, subida, bajaDeLaPrimera, a),
    TramoAPie(
        desde: bajaDeLaPrimera.punto,
        hasta: subeALaSegunda.punto,
        metros: cambio.caminata),
    _enBus(segunda, subeALaSegunda, bajada, b),
    TramoAPie(desde: bajada.punto, hasta: destino.punto, metros: baja.desvio),
  ]);
}

PuntoDeRuta _punto(RutaDeLaRed ruta, double avance, double caminata) =>
    PuntoDeRuta(
      ruta: ruta.id,
      avance: avance,
      punto: ruta.medible.puntoEn(avance),
      caminata: caminata,
    );

TramoEnBus _enBus(RutaDeLaRed ruta, PuntoDeRuta subida, PuntoDeRuta bajada,
        double metros) =>
    TramoEnBus(
      ruta: ruta.id,
      empresa: ruta.empresa,
      subida: subida,
      bajada: bajada,
      metrosPorLaRuta: metros,
    );
