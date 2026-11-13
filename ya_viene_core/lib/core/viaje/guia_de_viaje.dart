// El modo guiado del viaje (docs/viaje-completo.md, «Ir»): en qué parte va
// la persona, sacado de dónde está su teléfono y por dónde van los buses.
//
// Cada cambio de fase sale de una posición, nunca de un reloj: nadie sabe
// cuánto se demora un bus en Barranquilla, pero sí por dónde va. Y no se
// guarda nada: una guía cerrada a medias no se reanuda sola (regla 14).
import 'package:equatable/equatable.dart';

import '../geo/distancia.dart';
import '../geo/por_ruta.dart';
import '../models/bus_position.dart';
import '../models/route_trajectory.dart';
import 'bus_que_viene.dart';
import 'viaje.dart';

/// En qué va el viaje. La pantalla, la actividad en vivo y el aviso de
/// bajarse dicen lo que diga la fase; ninguno decide por su cuenta.
sealed class FaseDelViaje extends Equatable {
  const FaseDelViaje();

  @override
  List<Object?> get props => const [];
}

/// No hay ubicación del teléfono: sin ella no se sabe en qué va.
final class SinUbicacion extends FaseDelViaje {
  const SinUbicacion();
}

/// Va a pie hacia donde se toma la ruta.
final class CaminaALaSubida extends FaseDelViaje {
  const CaminaALaSubida({required this.metros, required this.bus});

  /// En línea recta hasta la subida.
  final double metros;

  /// El bus que viene, para saber si hay que apurarse. Null si no viene
  /// ninguno.
  final BusQueViene? bus;

  @override
  List<Object?> get props => [metros, bus];
}

/// Está donde se toma la ruta y el bus no ha llegado.
final class EsperaElBus extends FaseDelViaje {
  const EsperaElBus({required this.bus});

  /// Null si no hay buses en vivo en la ruta. Con `alDia` en falso, el bus
  /// perdió la señal y esa es su última posición.
  final BusQueViene? bus;

  @override
  List<Object?> get props => [bus];
}

/// Está donde se toma la ruta y el bus ya llega.
final class Subete extends FaseDelViaje {
  const Subete(this.bus);

  final BusQueViene bus;

  @override
  List<Object?> get props => [bus];
}

/// Va en el bus.
final class EnElBus extends FaseDelViaje {
  const EnElBus({required this.metrosParaBajar});

  /// Por la ruta, hasta donde se baja.
  final double metrosParaBajar;

  @override
  List<Object?> get props => [metrosParaBajar];
}

/// Va en el bus y ya casi es donde se baja: el momento de pedir la parada.
final class BajateEnLaProxima extends FaseDelViaje {
  const BajateEnLaProxima({required this.metros});

  /// Por la ruta, hasta donde se baja.
  final double metros;

  @override
  List<Object?> get props => [metros];
}

/// Siguió en el bus más allá de donde se bajaba.
final class TePasaste extends FaseDelViaje {
  const TePasaste({required this.metros});

  /// En línea recta hasta donde sigue el viaje: el destino o el otro bus.
  final double metros;

  @override
  List<Object?> get props => [metros];
}

/// Iba en el bus y ya no va por la ruta, lejos todavía de donde se bajaba:
/// un desvío del bus o alguien que se bajó antes. No se adivina cuál.
final class FueraDeLaRuta extends FaseDelViaje {
  const FueraDeLaRuta({required this.metros});

  /// En línea recta hasta donde sigue el viaje: el destino o el otro bus.
  final double metros;

  @override
  List<Object?> get props => [metros];
}

/// Se bajó del último bus y va a pie a su destino.
final class CaminaAlDestino extends FaseDelViaje {
  const CaminaAlDestino({required this.metros});

  /// En línea recta hasta el destino.
  final double metros;

  @override
  List<Object?> get props => [metros];
}

/// Se bajó del primer bus y le falta el otro. El [siguiente] no se guía
/// solo: se sigue un bus a la vez, y la persona lo pide con
/// [GuiaDeViaje.tomarElSiguienteBus].
final class CambiaDeBus extends FaseDelViaje {
  const CambiaDeBus({required this.siguiente, required this.metros});

  final TramoEnBus siguiente;

  /// En línea recta hasta donde se toma el siguiente.
  final double metros;

  @override
  List<Object?> get props => [siguiente, metros];
}

/// Está en su destino. De aquí la guía no sale.
final class Llegaste extends FaseDelViaje {
  const Llegaste();
}

/// A esto o menos de la subida ya está en ella, y hasta [_seFueDeLaSubida]
/// sigue ahí: el GPS de un teléfono quieto baila unos 20 m, y sin la
/// holgura la pantalla alternaría entre «camina» y «espera».
const double _llegoALaSubida = 40;
const double _seFueDeLaSubida = 80;

/// Con el bus a esto o menos por la ruta, «súbete»: lo que anda en unos
/// 20 segundos, lo que toma pararse y hacerle la seña.
const double _yaLlega = 150;

/// Un bus en vivo a esto o menos del teléfono va con él. Es tanto porque la
/// posición del bus puede tener hasta 15 s, y a 60 km/h son 250 m.
const double _juntoAlBus = 250;

/// Lo que hay que avanzar por la ruta, más allá de la subida, para decir
/// que va en el bus. Junto a un bus bastan 120 m, más de lo que baila el
/// GPS y de lo que alguien se corre a esperar en la otra esquina. Sin un
/// bus al lado (perdió la señal) son 300 m: nadie camina tres cuadras por
/// la ruta, más allá de donde la iba a tomar, sin haberse subido.
const double _subioJuntoAUnBus = 120;
const double _subioSinBusALaVista = 300;

/// Faltando esto se avisa que se baje: a 30 km/h son 48 s, lo que toma
/// pararse, llegar a la puerta y pedir la parada.
const double _avisoDeBajada = 400;

/// A esto o menos de la bajada, el bus ya está en ella.
const double _enLaBajada = 40;

/// Más de esto después de la bajada, todavía en la ruta, se pasó. Quien se
/// bajó y camina a su destino no cae aquí: se aleja de la ruta, y el punto
/// más cerca de ella sigue siendo su bajada.
const double _sePaso = 150;

/// A esto o menos del destino, llegó.
const double _llegada = 40;

/// La ventana donde se busca el teléfono sobre la ruta: desde un poco
/// antes de por donde iba hasta lo que pudo andar entre dos lecturas. Así
/// no salta al otro carril de una calle de ida y vuelta. Si ahí no está
/// (la app estuvo suspendida), se busca en todo el tramo y hasta
/// [_despuesDeLaBajada] más allá.
const double _atras = 50;
const double _adelante = 800;
const double _despuesDeLaBajada = 1500;

/// Guía un [Viaje], un bus a la vez (D19): con cada lectura dice en qué
/// fase va.
class GuiaDeViaje {
  /// [seguidores] trae el de la ruta de cada tramo en bus de [viaje], en
  /// su orden.
  GuiaDeViaje(this.viaje, {required List<SeguidorRuta> seguidores})
      : assert(seguidores.length == viaje.buses),
        _seguidores = seguidores;

  final Viaje viaje;
  final List<SeguidorRuta> _seguidores;

  var _indice = 0;
  var _enLaSubida = false;
  var _aBordo = false;
  var _avisado = false;
  var _llego = false;

  /// Metros por la ruta desde la subida, la última vez que el teléfono
  /// estuvo sobre ella yendo en el bus.
  double _progreso = 0;

  /// El tramo en bus que se está guiando.
  TramoEnBus get tramo => viaje.enBus[_indice];

  bool get _esElUltimo => _indice == viaje.buses - 1;

  /// Pasa a guiar el siguiente bus de un viaje con cambio. En el último
  /// no hace nada.
  void tomarElSiguienteBus() {
    if (_esElUltimo) return;
    _indice++;
    _enLaSubida = _aBordo = _avisado = false;
    _progreso = 0;
  }

  /// La fase del viaje con el teléfono en [telefono] (null sin ubicación)
  /// y los [buses] que se ven ahora.
  FaseDelViaje leer({
    required GeoPoint? telefono,
    Iterable<BusPosition> buses = const [],
  }) {
    if (_llego) return const Llegaste();
    if (telefono == null) return const SinUbicacion();
    final enRuta = _sobreElTramo(telefono);
    final vaPorLaRuta = enRuta.desvio <= desvioBusMaximo;

    if (!_aBordo) {
      final juntoAUnBus = buses.any((bus) =>
          bus.routeId == tramo.ruta &&
          !bus.isGhostBus &&
          _metros(telefono, GeoPoint(lat: bus.lat, lon: bus.lon)) <=
              _juntoAlBus);
      _aBordo = vaPorLaRuta &&
          enRuta.progreso >=
              (juntoAUnBus ? _subioJuntoAUnBus : _subioSinBusALaVista);
      if (!_aBordo) {
        final metros = _metros(telefono, tramo.subida.punto);
        // Quien esperaba y avanza por la ruta no se devuelve a «camina»:
        // o se corrió a la otra esquina o va en un bus que aún no se ve.
        _enLaSubida =
            metros <= (_enLaSubida ? _seFueDeLaSubida : _llegoALaSubida) ||
                (_enLaSubida && vaPorLaRuta && enRuta.progreso > 0);
        final viene = busQueViene(tramo, buses, _seguidores[_indice]);
        if (!_enLaSubida) return CaminaALaSubida(metros: metros, bus: viene);
        return viene != null &&
                viene.alDia &&
                viene.metrosHastaLaSubida <= _yaLlega
            ? Subete(viene)
            : EsperaElBus(bus: viene);
      }
    }

    if (vaPorLaRuta) _progreso = enRuta.progreso;
    final falta = tramo.metrosPorLaRuta - _progreso;
    final siguiente = _esElUltimo ? null : viaje.enBus[_indice + 1];
    final alFinal =
        _metros(telefono, siguiente?.subida.punto ?? viaje.destino.punto);
    if (siguiente == null && alFinal <= _llegada) {
      _llego = true;
      return const Llegaste();
    }
    final aPie = siguiente == null
        ? CaminaAlDestino(metros: alFinal)
        : CambiaDeBus(siguiente: siguiente, metros: alFinal);
    if (!vaPorLaRuta) {
      return falta > _avisoDeBajada ? FueraDeLaRuta(metros: alFinal) : aPie;
    }
    if (falta < -_sePaso) return TePasaste(metros: alFinal);
    if (falta <= _enLaBajada) return aPie;
    if (falta <= _avisoDeBajada) _avisado = true;
    return _avisado
        ? BajateEnLaProxima(metros: falta)
        : EnElBus(metrosParaBajar: falta);
  }

  /// Dónde cae el teléfono sobre el tramo: `progreso`, metros por la ruta
  /// desde la subida (negativo si está antes), y su `desvio` de la línea.
  ({double progreso, double desvio}) _sobreElTramo(GeoPoint telefono) {
    final ruta = _seguidores[_indice].ruta;
    final subida = tramo.subida.avance;
    var en = ruta.proyectarEntre(
        telefono, subida + _progreso - _atras, subida + _progreso + _adelante);
    if (en.desvio > desvioBusMaximo) {
      en = ruta.proyectarEntre(telefono, subida - _atras,
          subida + tramo.metrosPorLaRuta + _despuesDeLaBajada);
    }
    return (
      // En la circular el avance vuelve a cero al cerrar la vuelta.
      progreso: ruta.circular
          ? (en.avance - subida + _atras) % ruta.largo - _atras
          : en.avance - subida,
      desvio: en.desvio,
    );
  }
}

double _metros(GeoPoint a, GeoPoint b) =>
    haversineMeters(a.lat, a.lon, b.lat, b.lon);
