import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

/// Un bus como llega por el socket, con los dos instantes que interesan.
Map<String, dynamic> bus({
  int? capturado,
  int? emitido,
  bool fantasma = false,
}) =>
    {
      'busId': 'BUS-1',
      'routeId': 'R-101',
      'lat': 10.98,
      'lon': -74.78,
      if (capturado != null) 'capturedAt': capturado,
      if (emitido != null) 'emittedAt': emitido,
      'isGhost': fantasma,
    };

DateTime enMs(int ms) => DateTime.fromMillisecondsSinceEpoch(ms);

void main() {
  test('sin muestras el resumen está vacío y no divide por cero', () {
    final resumen = MedidorLatencia().resumen;
    expect(resumen.muestrasEmision, 0);
    expect(resumen.muestrasCaptura, 0);
    expect(resumen.emisionP50, isNull);
    expect(resumen.capturaP95, isNull);
    expect(resumen.desfaseMs, isNull);
    expect(resumen.hayDatos, isFalse);
  });

  test('mide los dos tramos del viaje de una posición', () {
    final medidor = MedidorLatencia();
    // Capturada en 1000, emitida en 1300, recibida en 1400.
    medidor.registrar(
      bus(capturado: 1000, emitido: 1300),
      recibidoEn: enMs(1400),
    );
    medidor.registrar(
      bus(capturado: 2000, emitido: 2500),
      recibidoEn: enMs(2700),
    );
    final resumen = medidor.resumen;
    expect(resumen.muestrasEmision, 2);
    expect(resumen.muestrasCaptura, 2);
    // El mínimo de cada serie es el desfase que se resta: la mejor muestra
    // queda en cero y las demás dicen cuánto peor fueron.
    expect(resumen.emisionP50, 100);
    expect(resumen.emisionMax, 100);
    expect(resumen.capturaMax, 300);
    expect(resumen.desfaseMs, 100);
    expect(resumen.hayDatos, isTrue);
  });

  test('un reloj corrido no inventa latencia', () {
    // El teléfono va 30 s adelantado: todas las muestras crudas traen esos
    // 30 s de más, y ninguna latencia real cambió.
    const desfase = 30000;
    final medidor = MedidorLatencia();
    for (final (captura, emision) in [(500, 100), (520, 120), (700, 300)]) {
      medidor.registrar(
        bus(capturado: 10000 - captura, emitido: 10000 - emision),
        recibidoEn: enMs(10000 + desfase),
      );
    }
    final resumen = medidor.resumen;
    expect(resumen.emisionMax, 200); // 300 - 100
    expect(resumen.capturaMax, 200); // 700 - 500
    expect(resumen.desfaseMs, desfase + 100);
  });

  test('no cuenta la captura de un bus sin señal ni la de hace horas', () {
    final medidor = MedidorLatencia();
    medidor.registrar(
      bus(capturado: 1000, emitido: 1200),
      recibidoEn: enMs(1300),
    );
    // Sin señal: su fecha vieja es lo que se enseña, no un retraso.
    medidor.registrar(
      bus(capturado: 1000 - 3600000, emitido: 1200, fantasma: true),
      recibidoEn: enMs(1300),
    );
    // En vivo pero de hace una hora: tampoco es latencia que se pueda creer.
    medidor.registrar(
      bus(capturado: 1000 - 3600000, emitido: 1200),
      recibidoEn: enMs(1300),
    );
    final resumen = medidor.resumen;
    expect(resumen.muestrasCaptura, 1);
    expect(resumen.capturaMax, 0);
    // La emisión sí cuenta en los tres: el servidor las mandó ahora.
    expect(resumen.muestrasEmision, 3);
  });

  test('sin los instantes del servidor no hay nada que medir', () {
    final medidor = MedidorLatencia();
    medidor.registrar(bus(), recibidoEn: enMs(1000));
    medidor.registrar({'busId': 'BUS-1'}, recibidoEn: enMs(1000));
    expect(medidor.resumen.hayDatos, isFalse);
  });

  test('guarda solo las últimas muestras y no crece sin fin', () {
    final medidor = MedidorLatencia(maximoMuestras: 3);
    for (var i = 0; i < 50; i++) {
      medidor.registrar(
        bus(capturado: 0, emitido: i * 10),
        recibidoEn: enMs(i * 10 + 500),
      );
    }
    expect(medidor.resumen.muestrasEmision, 3);
    expect(medidor.resumen.muestrasCaptura, 3);
    // Las tres últimas son todas de 500 ms: la latencia no se dispara con el
    // tiempo aunque `capturedAt` se quede quieto.
    expect(medidor.resumen.emisionMax, 0);
  });

  test('los percentiles salen de la muestra ordenada', () {
    final medidor = MedidorLatencia();
    for (final retraso in [50, 10, 90, 20, 30, 40, 60, 70, 80, 100]) {
      medidor.registrar(
        bus(emitido: 1000),
        recibidoEn: enMs(1000 + retraso),
      );
    }
    final resumen = medidor.resumen;
    // Restado el mínimo (10): 0, 10, 20, 30, 40, 50, 60, 70, 80, 90.
    expect(resumen.emisionP50, 50);
    expect(resumen.emisionP95, 90);
    expect(resumen.emisionMax, 90);
  });

  test('limpiar deja el medidor como recién hecho', () {
    final medidor = MedidorLatencia();
    medidor.registrar(bus(capturado: 1, emitido: 2), recibidoEn: enMs(3));
    medidor.limpiar();
    expect(medidor.resumen.hayDatos, isFalse);
  });
}
