// Distancia por la ruta, no en línea recta.
//
// Un bus a 400 m en línea recta puede tener 3 km de recorrido por delante
// antes de pasar por donde espera la persona, y en una calle de ida y vuelta
// el tramo más cercano puede ser el del sentido contrario. Aquí se mide lo
// que el bus tiene que andar: dónde cae él sobre el recorrido (su avance),
// dónde cae el punto, y los metros de ruta que hay entre los dos.
//
// Es la etapa 1 de alongroute (github.com/elDiego5599/alongroute): las
// ideas se prueban aquí, en Dart puro y sin Flutter, y el paquete abierto
// sale de este archivo cuando haya trazas de GPS real.
import 'dart:math' as math;

import '../models/bus_position.dart';
import '../models/route_trajectory.dart';

/// Dónde cae un punto sobre la ruta: [avance], metros desde el inicio del
/// recorrido, y [desvio], metros del punto a la línea.
typedef Proyeccion = ({double avance, double desvio});

/// Inicio y fin a menos de esto: la ruta vuelve a empezar (las de
/// `rutas.json` cierran a 0–33 m).
const double _cierreCircular = 50;

/// Velocidad más alta que se le cree a un bus urbano, 90 km/h: acota cuánto
/// pudo avanzar entre dos posiciones.
const double _vMax = 25;

/// La ventana tras una posición conocida: hasta 50 m atrás (el ruido del
/// GPS) y lo que pudo andar a [_vMax] más 100 m de holgura.
const double _ventanaAtras = 50;
const double _ventanaAdelante = 100;

/// Dos tramos a menos de esto en desvío son la misma calle (ida y vuelta,
/// un carril por sentido): ahí decide el rumbo, no la cercanía.
const double _empate = 15;

/// Un bus más lejos de la ruta no va por ella (desvío por obra, otra ruta,
/// GPS perdido): no se mide por la ruta.
const double desvioBusMaximo = 60;

/// Un recorrido listo para medir: coordenadas planas en metros con origen
/// en la ruta (error menor del 0,1 % a escala de ciudad) y largos
/// acumulados.
class RutaMedible {
  RutaMedible._(this._x, this._y, this._acum, this.circular, this._lat0,
      this._lon0, this._kx);

  final List<double> _x;
  final List<double> _y;

  /// Avance en cada vértice; el último es [largo].
  final List<double> _acum;

  /// La ruta vuelve a empezar al final: el avance da la vuelta.
  final bool circular;
  final double _lat0;
  final double _lon0;
  final double _kx;
  static const double _ky = 111320;

  double get largo => _acum.last;

  /// Null si [puntos] no tiene un solo tramo con largo: eso es no saber,
  /// no estar lejos.
  static RutaMedible? de(List<GeoPoint> puntos) {
    if (puntos.length < 2) return null;
    var lat0 = 0.0, lon0 = 0.0;
    for (final p in puntos) {
      lat0 += p.lat;
      lon0 += p.lon;
    }
    lat0 /= puntos.length;
    lon0 /= puntos.length;
    final kx = _ky * math.cos(lat0 * math.pi / 180);
    final x = [for (final p in puntos) (p.lon - lon0) * kx];
    final y = [for (final p in puntos) (p.lat - lat0) * _ky];
    final cierre = math
        .sqrt(math.pow(x.last - x.first, 2) + math.pow(y.last - y.first, 2));
    final circular = cierre < _cierreCircular;
    // En la circular, el tramo del final al inicio también es ruta.
    if (circular && cierre > 0) {
      x.add(x.first);
      y.add(y.first);
    }
    final acum = [0.0];
    for (var i = 1; i < x.length; i++) {
      acum.add(acum.last +
          math.sqrt(
              math.pow(x[i] - x[i - 1], 2) + math.pow(y[i] - y[i - 1], 2)));
    }
    if (acum.last <= 0) return null;
    return RutaMedible._(x, y, acum, circular, lat0, lon0, kx);
  }

  /// Metros de ruta entre [desde] y [hasta], hacia adelante o hacia atrás,
  /// lo que sea menos: en la circular, también cruzando el inicio.
  double _entre(double desde, double hasta) {
    final d = (hasta - desde).abs();
    return circular ? math.min(d, largo - d) : d;
  }

  /// Lo que anda el bus de [desde] a [hasta] en el sentido de la ruta, o
  /// null si [hasta] queda atrás y la ruta no vuelve a empezar: el bus no
  /// se devuelve. En la circular, hacia atrás es dar la vuelta. Para un
  /// viaje no sirve [_entre], que toma el sentido más corto.
  double? recorridoDirigido(double desde, double hasta) {
    if (circular) return (hasta - desde) % largo;
    return hasta >= desde ? hasta - desde : null;
  }

  /// Cada paso de la ruta a [maximo] metros o menos de [p], en orden de
  /// avance: donde se puede subir o bajar caminando desde ahí. El desvío
  /// de cada uno es esa caminata, en línea recta.
  List<Proyeccion> pasosCerca(GeoPoint p, double maximo) => _pasos(p, maximo);

  /// El punto de la ruta en [avance].
  GeoPoint puntoEn(double avance) => _geo(_sobre(avance));

  /// Cada tramo con la proyección de ([px], [py]) sobre él.
  Iterable<({int tramo, double avance, double desvio})> _proyecciones(
      double px, double py) sync* {
    for (var i = 0; i + 1 < _x.length; i++) {
      final largoTramo = _acum[i + 1] - _acum[i];
      if (largoTramo == 0) continue;
      final dx = _x[i + 1] - _x[i], dy = _y[i + 1] - _y[i];
      final t =
          (((px - _x[i]) * dx + (py - _y[i]) * dy) / (largoTramo * largoTramo))
              .clamp(0.0, 1.0);
      yield (
        tramo: i,
        avance: _acum[i] + t * largoTramo,
        desvio: math.sqrt(math.pow(px - _x[i] - t * dx, 2) +
            math.pow(py - _y[i] - t * dy, 2)),
      );
    }
  }

  (double, double) _plano(GeoPoint p) =>
      ((p.lon - _lon0) * _kx, (p.lat - _lat0) * _ky);

  /// Rumbo del tramo [i] en grados, 0 el norte y 90 el este.
  double _rumbo(int i) =>
      math.atan2(_x[i + 1] - _x[i], _y[i + 1] - _y[i]) * 180 / math.pi;

  /// El punto sobre la ruta de [p], buscando en toda ella. Si dos tramos
  /// empatan (a menos de [_empate] en desvío), gana el que va en el sentido
  /// de [rumbo]; sin rumbo, el más cercano.
  Proyeccion proyectar(GeoPoint p, {double? rumbo}) {
    final (px, py) = _plano(p);
    final todas = _proyecciones(px, py).toList();
    final mejor = todas.map((c) => c.desvio).reduce(math.min);
    var elegida = todas.firstWhere((c) => c.desvio == mejor);
    if (rumbo != null) {
      double giro(int i) {
        final d = (_rumbo(i) - rumbo).abs() % 360;
        return d > 180 ? 360 - d : d;
      }

      for (final c in todas) {
        if (c.desvio > mejor + _empate) continue;
        final g = giro(c.tramo), ge = giro(elegida.tramo);
        if (g < ge || (g == ge && c.desvio < elegida.desvio)) elegida = c;
      }
    }
    return (avance: elegida.avance, desvio: elegida.desvio);
  }

  /// Donde la persona del pin [p] toma el bus: el punto de la ruta más
  /// cerca de él. El pin marca dónde se toma la ruta, no dónde está la
  /// persona, y el mapa lo lleva hasta aquí (dueño, 2026-11-05).
  GeoPoint puntoDeEspera(GeoPoint p) => _geo(_sobre(proyectar(p).avance));

  GeoPoint _geo((double, double) xy) =>
      GeoPoint(lat: _lat0 + xy.$2 / _ky, lon: _lon0 + xy.$1 / _kx);

  /// El punto plano de la ruta en [avance].
  (double, double) _sobre(double avance) {
    final i = _tramoDe(avance);
    return _acum[i + 1] > _acum[i] ? _enAvance(i, avance) : (_x[i], _y[i]);
  }

  /// El tramo donde cae [avance]: el primero que termina en él o después.
  int _tramoDe(double avance) {
    var bajo = 0, alto = _acum.length - 2;
    while (bajo < alto) {
      final medio = (bajo + alto) >> 1;
      if (_acum[medio + 1] < avance) {
        bajo = medio + 1;
      } else {
        alto = medio;
      }
    }
    return bajo;
  }

  /// Como [proyectar], pero solo entre los avances [desde] y [hasta] (con la
  /// vuelta en la circular) y sin recorrer el resto de la ruta: es lo que
  /// hace barato seguir un bus y buscar dónde se cruzan dos rutas. Lo que
  /// la ventana corta de un tramo se mide hasta su borde.
  Proyeccion proyectarEntre(GeoPoint p, double desde, double hasta) {
    if (hasta - desde >= largo) return proyectar(p);
    final (px, py) = _plano(p);
    Proyeccion? mejor;
    void medir(double desde, double hasta) {
      for (var i = _tramoDe(desde);
          i + 1 < _x.length && _acum[i] <= hasta;
          i++) {
        final largoTramo = _acum[i + 1] - _acum[i];
        if (largoTramo == 0) continue;
        final dx = _x[i + 1] - _x[i], dy = _y[i + 1] - _y[i];
        final t = (((px - _x[i]) * dx + (py - _y[i]) * dy) /
                (largoTramo * largoTramo))
            .clamp(
          math.max(0.0, (desde - _acum[i]) / largoTramo),
          math.min(1.0, (hasta - _acum[i]) / largoTramo),
        );
        final desvio = math.sqrt(math.pow(px - _x[i] - t * dx, 2) +
            math.pow(py - _y[i] - t * dy, 2));
        if (mejor == null || desvio < mejor!.desvio) {
          mejor = (avance: _acum[i] + t * largoTramo, desvio: desvio);
        }
      }
    }

    if (!circular) {
      desde = math.max(0, desde);
      hasta = math.min(largo, hasta);
      if (desde <= hasta) medir(desde, hasta);
    } else {
      final inicio = desde % largo;
      final fin = inicio + (hasta - desde);
      if (fin <= largo) {
        medir(inicio, fin);
      } else {
        // La ventana cruza el inicio de la ruta: son dos pedazos.
        medir(inicio, largo);
        medir(0, fin - largo);
      }
    }
    return mejor ?? proyectar(p);
  }

  (double, double) _enAvance(int i, double avance) {
    final t = (avance - _acum[i]) / (_acum[i + 1] - _acum[i]);
    return (
      _x[i] + t * (_x[i + 1] - _x[i]),
      _y[i] + t * (_y[i + 1] - _y[i]),
    );
  }

  /// Cada paso de la ruta cerca de [p]: en una calle de ida y vuelta, el
  /// punto cae en las dos. Un paso es donde la ruta más se acerca a [p]
  /// antes de alejarse otra vez (ningún tramo vecino queda más cerca), a
  /// [maximo] o menos; los tramos seguidos que caen en el mismo
  /// sitio (una esquina) son un paso.
  List<Proyeccion> _pasos(GeoPoint p, double maximo) {
    final (px, py) = _plano(p);
    final todas = _proyecciones(px, py).toList();
    final n = todas.length;
    bool minimo(int i) {
      final antes = i > 0 ? i - 1 : (circular ? n - 1 : null);
      final despues = i < n - 1 ? i + 1 : (circular ? 0 : null);
      return (antes == null || todas[i].desvio <= todas[antes].desvio) &&
          (despues == null || todas[i].desvio <= todas[despues].desvio);
    }

    final cerca = [
      for (var i = 0; i < n; i++)
        if (todas[i].desvio <= maximo && minimo(i))
          (avance: todas[i].avance, desvio: todas[i].desvio)
    ]..sort((a, b) => a.avance.compareTo(b.avance));
    const mismoPaso = 2 * _empate;
    final pasos = <Proyeccion>[];
    for (final c in cerca) {
      if (pasos.isNotEmpty && c.avance - pasos.last.avance < mismoPaso) {
        if (c.desvio < pasos.last.desvio) pasos.last = c;
      } else {
        pasos.add(c);
      }
    }
    // En la circular, el último y el primero pueden ser el mismo paso.
    if (circular &&
        pasos.length > 1 &&
        pasos.first.avance + largo - pasos.last.avance < mismoPaso) {
      final ultimo = pasos.removeLast();
      if (ultimo.desvio < pasos.first.desvio) pasos.first = ultimo;
    }
    return pasos;
  }

  /// Los avances donde la ruta pasa por el [puntoDeEspera] de [p]: el
  /// suyo y, donde la ruta vuelve por ese sitio (el otro carril de una
  /// calle de ida y vuelta), también ese.
  List<double> pasosPorLaEspera(GeoPoint p) =>
      [for (final paso in _sitio(proyectar(p))) paso.avance];

  /// Los pasos a menos de dos [_empate] del punto de espera: más lejos ya
  /// es otra calle.
  List<Proyeccion> _sitio(Proyeccion espera) =>
      _pasos(_geo(_sobre(espera.avance)), 2 * _empate);

  /// Los metros de ruta, desde el más cerca de los [avances] del bus, al
  /// [puntoDeEspera] de [p], venga o ya haya pasado. No se suma el camino
  /// del pin a la ruta: el bus nunca pasa por ahí (dueño, 2026-11-05).
  ///
  /// Nunca cuenta la vuelta entera: un bus que acaba de pasar decía 20 km
  /// con el bus a la vista; se muestra lo que hay y qué bus elige es cosa
  /// de la persona (dueño, 2026-10-19).
  ///
  /// Se espera en un solo sitio, el punto de la ruta más cerca del pin, y
  /// desde cualquier distancia: no se sabe hacia qué calle caminará la
  /// persona, y adivinarlo hacía saltar la cifra. Con un tope de 300 m a
  /// la línea recta y contando las calles hasta 300 m más lejos que la más
  /// cercana, correr el pin 50 m cambiaba de 5,8 a 19,3 km en las 15 rutas
  /// (dueño, 2026-11-04). Ahora la cifra solo salta con el pin a mitad de
  /// camino entre dos calles de la ruta, donde de verdad cambia la calle
  /// en que se espera, y el pin salta a ella. Donde la ruta
  /// pasa otra vez por ese sitio (el otro carril de una calle de ida y
  /// vuelta, a menos de dos [_empate]) también se espera: cuenta el paso
  /// que trae el bus más cerca. Esos pasos se buscan desde el sitio, no
  /// desde el pin: buscados desde el pin a 800 m, los de un retorno de
  /// 180 m aparecían y se iban, y la cifra se turnaba. Donde los dos
  /// carriles se separan más que eso, el otro deja de pasar por el sitio y
  /// la cifra cambia (menos del 3 % de los pines vecinos en las 15 rutas).
  double _desde(List<double> avances, GeoPoint p) {
    final sitio = _sitio(proyectar(p));
    return [
      for (final a in avances)
        for (final paso in sitio) _entre(a, paso.avance)
    ].reduce(math.min);
  }
}

/// El avance de cada bus de una ruta, recordado entre posiciones: con el
/// avance anterior solo se busca en la ventana que el bus pudo andar, y así
/// no salta al carril contrario de una calle de ida y vuelta.
class SeguidorRuta {
  SeguidorRuta(this.ruta);

  final RutaMedible ruta;
  final _ultimo = <String, ({double avance, DateTime t})>{};

  /// El avance de [bus], o null si va a más de [desvioBusMaximo] de la
  /// ruta. Una posición igual o más vieja que la última no mueve nada.
  double? avanceDe(BusPosition bus) {
    final previo = _ultimo[bus.busId];
    if (previo != null && !bus.timestamp.isAfter(previo.t)) {
      return previo.avance;
    }
    final p = GeoPoint(lat: bus.lat, lon: bus.lon);
    Proyeccion? pr;
    if (previo != null) {
      final dt = bus.timestamp.difference(previo.t).inMilliseconds / 1000;
      pr = ruta.proyectarEntre(p, previo.avance - _ventanaAtras,
          previo.avance + _vMax * dt + _ventanaAdelante);
      // Fuera de la ventana no es seguir: se busca en toda la ruta.
      if (pr.desvio > desvioBusMaximo) pr = null;
    }
    pr ??= ruta.proyectar(p, rumbo: bus.heading);
    if (pr.desvio > desvioBusMaximo) {
      _ultimo.remove(bus.busId);
      return null;
    }
    _ultimo[bus.busId] = (avance: pr.avance, t: bus.timestamp);
    return pr.avance;
  }

  /// Lo que le falta a [bus] por la ruta hasta [punto], o null si el bus va
  /// fuera de ella.
  ///
  /// Se mide desde cada paso de la ruta por donde está el bus, no solo
  /// desde su carril: dos buses lado a lado, uno de ida y otro de vuelta,
  /// decían 10 y 29 km, porque al de la vuelta se le contaba la vuelta que
  /// le faltaba (dueño, 2026-10-19). Están en la misma calle y dicen lo
  /// mismo.
  double? distancia(BusPosition bus, GeoPoint punto) {
    final avance = avanceDe(bus);
    if (avance == null) return null;
    final aqui =
        ruta._pasos(GeoPoint(lat: bus.lat, lon: bus.lon), desvioBusMaximo);
    return ruta._desde([avance, for (final p in aqui) p.avance], punto);
  }
}
