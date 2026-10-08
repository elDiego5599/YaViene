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

/// Un bus hasta 30 m pasado el punto sigue ahí: es el error del GPS, no
/// que le falte otra vuelta.
const double _ruidoAtras = 30;

/// Dos tramos a menos de esto en desvío son la misma calle (ida y vuelta,
/// un carril por sentido): ahí decide el rumbo, no la cercanía.
const double _empate = 15;

/// Un bus más lejos de la ruta no va por ella (desvío por obra, otra ruta,
/// GPS perdido): no se mide por la ruta.
const double desvioBusMaximo = 60;

/// Un punto más lejos de la ruta no espera ese bus en esa calle: se mide en
/// línea recta (alongroute, `maxStopOffset`).
const double desvioPuntoMaximo = 300;

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

  /// Metros hacia adelante de [desde] a [hasta]: con la vuelta en la
  /// circular; null en la abierta si [hasta] queda atrás. Menos de
  /// [_ruidoAtras] por detrás es el error del GPS: 0, no una vuelta entera.
  double? _adelante(double desde, double hasta) {
    final d = hasta - desde;
    if (circular) {
      final a = d % largo;
      return largo - a < _ruidoAtras ? 0 : a;
    }
    if (d < 0) return d > -_ruidoAtras ? 0 : null;
    return d;
  }

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

  /// Como [proyectar], pero solo entre los avances [desde] y [hasta] (con la
  /// vuelta en la circular). Lo que la ventana corta de un tramo se mide
  /// hasta su borde.
  Proyeccion _enVentana(GeoPoint p, double desde, double hasta) {
    if (hasta - desde >= largo) return proyectar(p);
    if (!circular) {
      desde = math.max(0, desde);
      hasta = math.min(largo, hasta);
    }
    final (px, py) = _plano(p);
    final ancho = hasta - desde;
    bool dentro(double a) =>
        circular ? (a - desde) % largo <= ancho : a >= desde && a <= hasta;
    Proyeccion? mejor;
    void probar(double avance, double desvio) {
      if (mejor == null || desvio < mejor!.desvio) {
        mejor = (avance: avance, desvio: desvio);
      }
    }

    for (final c in _proyecciones(px, py)) {
      if (dentro(c.avance)) {
        probar(c.avance, c.desvio);
        continue;
      }
      // Fuera: lo más cerca dentro del tramo es uno de los bordes.
      for (final borde in [desde, hasta]) {
        final a = circular ? borde % largo : borde;
        if (a < _acum[c.tramo] || a > _acum[c.tramo + 1]) continue;
        final (bx, by) = _enAvance(c.tramo, a);
        probar(a, math.sqrt(math.pow(px - bx, 2) + math.pow(py - by, 2)));
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
  /// punto cae en las dos. Pasos a menos de [_empate] del más cercano; los
  /// tramos seguidos que caen en el mismo sitio (una esquina) son un paso.
  List<Proyeccion> _pasos(GeoPoint p) {
    final (px, py) = _plano(p);
    final todas = _proyecciones(px, py).toList();
    final mejor = todas.map((c) => c.desvio).reduce(math.min);
    final cerca = [
      for (final c in todas)
        if (c.desvio <= mejor + _empate) (avance: c.avance, desvio: c.desvio)
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

  /// Los metros que le faltan al bus en [avanceBus] para pasar por [p]: los
  /// de ruta hasta el próximo paso por [p] más el desvío del punto a la
  /// línea. Null si [p] está a más de [desvioPuntoMaximo] de la ruta o, en
  /// la abierta, si el bus ya dejó atrás todos los pasos.
  ///
  /// Nunca dice «ya pasó»: en una calle de ida y vuelta no se sabe qué
  /// sentido espera la persona, así que en la circular se cuenta hasta la
  /// vuelta siguiente; qué bus elige es cosa suya (dueño, 2026-10-08).
  double? medir(double avanceBus, GeoPoint p) {
    final pasos = _pasos(p);
    if (pasos.first.desvio > desvioPuntoMaximo) return null;
    double? faltan;
    for (final paso in pasos) {
      final adelante = _adelante(avanceBus, paso.avance);
      if (adelante == null) continue;
      final metros = adelante + paso.desvio;
      if (faltan == null || metros < faltan) faltan = metros;
    }
    return faltan;
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
      pr = ruta._enVentana(p, previo.avance - _ventanaAtras,
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

  /// Lo que le falta a [bus] por la ruta hasta [punto], o null si no se
  /// sabe: el bus fuera de la ruta o el punto lejos de ella.
  double? distancia(BusPosition bus, GeoPoint punto) {
    final avance = avanceDe(bus);
    return avance == null ? null : ruta.medir(avance, punto);
  }
}
