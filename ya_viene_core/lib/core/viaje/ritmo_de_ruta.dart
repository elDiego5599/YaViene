// La hora de llegada honesta (D24): un rango sacado de lo que de verdad
// avanzaron los buses de la ruta mientras la app los veía, no de un horario
// ni de una velocidad supuesta. Si no ha visto lo suficiente, no dice nada.
import 'package:equatable/equatable.dart';

import '../geo/por_ruta.dart';
import '../models/bus_position.dart';

/// Entre cuánto y cuánto tarda un bus en recorrer un trecho de su ruta. Va
/// siempre junto a la distancia, nunca en su lugar.
class RangoDeLlegada extends Equatable {
  const RangoDeLlegada({
    required this.desde,
    required this.hasta,
    required this.simulado,
  });

  /// Al ritmo de los minutos rápidos que se vieron.
  final Duration desde;

  /// Al ritmo de los minutos lentos.
  final Duration hasta;

  /// Salió de buses de la flota de ejemplo: quien lo muestre le pone la
  /// etiqueta «Simulación».
  final bool simulado;

  @override
  List<Object?> get props => [desde, hasta, simulado];
}

/// Cada tramo dura al menos esto: en un minuto caben un semáforo y una
/// parada, así que su velocidad ya es un ritmo y no un arrancón.
const Duration _tramo = Duration(minutes: 1);

/// Más de esto sin posiciones de un bus y su tramo se corta: no se sabe qué
/// hizo mientras estuvo callado, y promediarlo sería inventarlo.
const Duration _hueco = Duration(minutes: 1);

/// Por debajo de esto (30 m en un minuto) el bus no anda, está parqueado
/// en su terminal o esperando turno: eso no es el ritmo de la ruta. Un
/// trancón total se ve igual; ahí el rango sigue siendo el de antes y a
/// los veinte minutos se calla.
const double _parqueado = 0.5;

/// Lo más que anda un bus, en m/s (90 km/h). Más que eso es un salto del
/// GPS o un bus que retrocedió en una ruta circular.
const double _vMax = 25;

/// El ritmo es el de ahora: lo que pasó hace más de esto ya no cuenta.
const Duration _vigencia = Duration(minutes: 20);

/// Con menos tramos que estos no hay de dónde sacar un rango: son seis
/// minutos de buses andando, entre todos los de la ruta.
const int _minimo = 6;

/// A qué ritmo andan los buses de una ruta, de verlos pasar.
class RitmoDeRuta {
  RitmoDeRuta(this._seguidor);

  final SeguidorRuta _seguidor;
  final _abiertos = <String, _TramoAbierto>{};
  final _medidos = <_TramoMedido>[];

  /// Anota una posición de un bus de la ruta. La misma dos veces no cuenta
  /// doble.
  void ver(BusPosition bus) {
    final avance = bus.isGhostBus ? null : _seguidor.avanceDe(bus);
    if (avance == null) {
      _abiertos.remove(bus.busId);
      return;
    }
    // La hora del equipo del bus, si viene: la del servidor trae además lo
    // que tardó la red.
    final cuando = bus.capturedAt != null
        ? DateTime.fromMillisecondsSinceEpoch(bus.capturedAt!)
        : bus.timestamp;
    final abierto = _abiertos[bus.busId];
    if (abierto == null || cuando.difference(abierto.ultima) > _hueco) {
      _abiertos[bus.busId] = _TramoAbierto(cuando, avance);
      return;
    }
    if (!cuando.isAfter(abierto.ultima)) return;
    abierto.ultima = cuando;
    final duracion = cuando.difference(abierto.inicio);
    if (duracion < _tramo) return;

    final segundos = duracion.inMilliseconds / 1000;
    final metros =
        _seguidor.ruta.recorridoDirigido(abierto.avanceInicial, avance);
    final velocidad = metros == null ? 0 : metros / segundos;
    if (velocidad >= _parqueado && velocidad <= _vMax) {
      _medidos.add(_TramoMedido(cuando, metros!, segundos, bus.simulado));
    }
    _medidos.removeWhere((t) => cuando.difference(t.fin) > _vigencia);
    _abiertos[bus.busId] = _TramoAbierto(cuando, avance);
  }

  /// Lo que tardaría un bus en recorrer [metros] de la ruta, o null si no
  /// se ha visto lo suficiente para decirlo.
  RangoDeLlegada? paraRecorrer(double metros) {
    if (_medidos.length < _minimo) return null;
    final porVelocidad = [..._medidos]
      ..sort((a, b) => a.velocidad.compareTo(b.velocidad));
    // Con un número impar, el del medio cuenta en las dos mitades.
    final mitad = (porVelocidad.length + 1) ~/ 2;
    final lenta = _velocidadDe(porVelocidad.take(mitad));
    final rapida = _velocidadDe(porVelocidad.skip(porVelocidad.length - mitad));
    return RangoDeLlegada(
      desde: _segundos(metros / rapida),
      hasta: _segundos(metros / lenta),
      simulado: _medidos.any((t) => t.simulado),
    );
  }
}

/// La velocidad de varios tramos juntos: lo que anduvieron entre lo que
/// duraron, no el promedio de sus velocidades.
double _velocidadDe(Iterable<_TramoMedido> tramos) {
  var metros = 0.0, segundos = 0.0;
  for (final tramo in tramos) {
    metros += tramo.metros;
    segundos += tramo.segundos;
  }
  return metros / segundos;
}

Duration _segundos(double segundos) => Duration(seconds: segundos.round());

class _TramoAbierto {
  _TramoAbierto(this.inicio, this.avanceInicial) : ultima = inicio;

  final DateTime inicio;
  final double avanceInicial;
  DateTime ultima;
}

class _TramoMedido {
  const _TramoMedido(this.fin, this.metros, this.segundos, this.simulado);

  final DateTime fin;
  final double metros;
  final double segundos;
  final bool simulado;

  double get velocidad => metros / segundos;
}
