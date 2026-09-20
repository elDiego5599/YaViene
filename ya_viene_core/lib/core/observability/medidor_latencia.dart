/// Cuánto tarda una posición en llegar del bus a la pantalla (T7.6).
///
/// El viaje tiene dos tramos y hasta ahora solo el servidor medía uno:
///
/// - **captura**: del equipo del bus al servidor (`capturedAt` → recibido);
/// - **emisión**: del servidor al teléfono (`emittedAt` → recibido).
///
/// El problema de medirlos desde la app es que los tres relojes son
/// distintos: el del equipo GPS, el del servidor y el del teléfono. Un
/// teléfono 30 s adelantado haría parecer que todo llega con 30 s de retraso.
/// Por eso de cada serie se resta su valor más pequeño: esa muestra es la que
/// menos se demoró, y lo que queda es cuánto peor fue cada una de las demás.
/// No da la latencia absoluta —para eso haría falta sincronizar relojes— pero
/// sí la dispersión, que es lo que se quiere vigilar.
///
/// Las muestras viven solo en memoria y no salen del teléfono: en depuración
/// se enseñan en un recuadro para el desarrollador y en release no se enseñan
/// ni se mandan a ninguna parte, como dice `privacidad.html`.
class MedidorLatencia {
  MedidorLatencia({this.maximoMuestras = 200})
      : assert(maximoMuestras > 0, 'hay que guardar al menos una muestra');

  /// Uno solo para toda la app: quien recibe posiciones apunta aquí y el
  /// recuadro de depuración lee de aquí, sin pasarse el medidor de mano en
  /// mano por media app.
  static final MedidorLatencia compartido = MedidorLatencia();

  /// Cuántas muestras se guardan de cada tramo. A una posición cada 200 ms,
  /// 200 muestras son los últimos 40 s: suficiente para ver un bache y poco
  /// para la memoria.
  final int maximoMuestras;

  final List<int> _captura = [];
  final List<int> _emision = [];

  /// Más allá de esto no es latencia sino una posición vieja: el bus lleva
  /// rato sin publicar y lo que se ve es su último punto conocido.
  static const Duration _capturaCreible = Duration(minutes: 5);

  /// Apunta lo que tardó en llegar [bus], tal como viene del socket o del
  /// REST. Lo que no traiga los instantes del servidor no se cuenta.
  void registrar(Map<String, dynamic> bus, {DateTime? recibidoEn}) {
    final recibido = (recibidoEn ?? DateTime.now()).millisecondsSinceEpoch;
    final emitido = (bus['emittedAt'] as num?)?.toInt();
    if (emitido != null) _guardar(_emision, recibido - emitido);
    final capturado = (bus['capturedAt'] as num?)?.toInt();
    // Un bus sin señal enseña a propósito su última posición, de hace un
    // rato: contarla sería medir el silencio del equipo, no la red.
    final fantasma = bus['isGhost'] as bool? ?? false;
    if (capturado != null && !fantasma) {
      _guardar(_captura, recibido - capturado);
    }
  }

  void _guardar(List<int> serie, int muestra) {
    serie.add(muestra);
    if (serie.length > maximoMuestras) {
      serie.removeRange(0, serie.length - maximoMuestras);
    }
  }

  /// Borra lo medido. Al cambiar de backend el desfase estimado ya no vale.
  void limpiar() {
    _captura.clear();
    _emision.clear();
  }

  ResumenLatencia get resumen {
    final emision = _relativas(_emision);
    final captura = _relativas(_captura)
        .where((ms) => ms <= _capturaCreible.inMilliseconds)
        .toList();
    return ResumenLatencia(
      muestrasEmision: emision.length,
      emisionP50: _percentil(emision, 0.5),
      emisionP95: _percentil(emision, 0.95),
      emisionMax: emision.isEmpty ? null : emision.last,
      muestrasCaptura: captura.length,
      capturaP50: _percentil(captura, 0.5),
      capturaP95: _percentil(captura, 0.95),
      capturaMax: captura.isEmpty ? null : captura.last,
      desfaseMs:
          _emision.isEmpty ? null : _emision.reduce((a, b) => a < b ? a : b),
    );
  }

  /// La serie ordenada y medida desde su mejor muestra, que es la que menos
  /// tardó: lo que sobra de las otras no depende de qué reloj se use.
  List<int> _relativas(List<int> serie) {
    if (serie.isEmpty) return const [];
    final ordenadas = [...serie]..sort();
    final minimo = ordenadas.first;
    return [for (final ms in ordenadas) ms - minimo];
  }

  static int? _percentil(List<int> ordenadas, double p) {
    if (ordenadas.isEmpty) return null;
    final i = (ordenadas.length * p).floor();
    return ordenadas[i.clamp(0, ordenadas.length - 1)];
  }
}

/// Lo medido hasta ahora, listo para enseñar.
class ResumenLatencia {
  const ResumenLatencia({
    required this.muestrasEmision,
    required this.emisionP50,
    required this.emisionP95,
    required this.emisionMax,
    required this.muestrasCaptura,
    required this.capturaP50,
    required this.capturaP95,
    required this.capturaMax,
    required this.desfaseMs,
  });

  final int muestrasEmision;
  final int? emisionP50;
  final int? emisionP95;
  final int? emisionMax;

  final int muestrasCaptura;
  final int? capturaP50;
  final int? capturaP95;
  final int? capturaMax;

  /// Lo que se le restó a la serie de emisión: reloj del teléfono contra el
  /// del servidor más la mejor latencia observada. No se puede separar lo uno
  /// de lo otro sin sincronizar relojes, así que se enseña tal cual.
  final int? desfaseMs;

  bool get hayDatos => muestrasEmision > 0 || muestrasCaptura > 0;
}
