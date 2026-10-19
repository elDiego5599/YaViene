import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

// El tramo animado de un bus, el mismo en el mapa del pasajero y en el del
// panel.
void main() {
  test('BusMotion dura 1 segundo', () {
    final start = DateTime(2024, 1, 1, 12, 0, 0);
    final m = BusMotion(
      fromLat: 0,
      fromLon: 0,
      fromHeading: 0,
      toLat: 1,
      toLon: 1,
      toHeading: 90,
      start: start,
    );
    expect(m.isFinished(start), isFalse);
    expect(
        m.isFinished(
          start.add(const Duration(milliseconds: 999)),
        ),
        isFalse);
    expect(
        m.isFinished(
          start.add(const Duration(milliseconds: 1000)),
        ),
        isTrue);
    expect(
        m.isFinished(
          start.add(const Duration(seconds: 2)),
        ),
        isTrue);
  });

  test('displayOf interpola lineal y heading por arco corto', () {
    final start = DateTime(2024, 1, 1, 12, 0, 0);
    final m = BusMotion(
      fromLat: 10,
      fromLon: 20,
      fromHeading: 350,
      toLat: 20,
      toLon: 40,
      toHeading: 10,
      start: start,
    );
    // t=0
    final at0 = displayOf(m, start);
    expect(at0.$1, closeTo(10, 0.01));
    expect(at0.$2, closeTo(20, 0.01));
    expect(at0.$3, closeTo(350, 0.01));
    final atHalf = displayOf(m, start.add(const Duration(milliseconds: 500)));
    expect(atHalf.$1, closeTo(15, 0.01));
    expect(atHalf.$2, closeTo(30, 0.01));
    // 350 -> 10 por arco corto: pasa por 0, nunca por 180.
    final girando = displayOf(m, start.add(const Duration(milliseconds: 100)));
    expect(girando.$3 > 350 || girando.$3 < 10, isTrue);
    // t=1
    final at1 = displayOf(m, start.add(const Duration(milliseconds: 1000)));
    expect(at1.$1, closeTo(20, 0.01));
    expect(at1.$2, closeTo(40, 0.01));
    expect(at1.$3, closeTo(10, 0.01));
  });

  test('de 10° a 350° gira 20° hacia atrás, no 340° hacia delante', () {
    final start = DateTime(2024, 1, 1, 12, 0, 0);
    final m = BusMotion(
      fromLat: 0,
      fromLon: 0,
      fromHeading: 10,
      toLat: 0,
      toLon: 0,
      toHeading: 350,
      start: start,
    );
    final girando = displayOf(m, start.add(const Duration(milliseconds: 100)));
    expect(girando.$3 > 350 || girando.$3 < 10, isTrue);
    expect(displayOf(m, start.add(BusMotion.giro)).$3, closeTo(350, 0.01));
  });

  // El bus gira en la esquina, no a lo largo del tramo: con un GPS cada 8 s
  // el giro lineal duraba 8 s y el bus avanzaba de lado. Gira con el
  // resorte de la app, sin pasarse (dueño, 2026-10-19).
  test('el giro va con resorte: arranca quieto, no se pasa y acaba pronto', () {
    final start = DateTime(2024, 1, 1, 12, 0, 0);
    final m = BusMotion(
      fromLat: 0,
      fromLon: 0,
      fromHeading: 0,
      toLat: 1,
      toLon: 1,
      toHeading: 90,
      start: start,
      duration: const Duration(seconds: 8),
    );
    double rumbo(int ms) =>
        displayOf(m, start.add(Duration(milliseconds: ms))).$3;
    expect(rumbo(0), closeTo(0, 0.01));
    // Más que el lineal de 8 s (1,1°), menos que un salto.
    expect(rumbo(100), inExclusiveRange(10, 60));
    var antes = 0.0;
    for (var ms = 0; ms <= BusMotion.giro.inMilliseconds; ms += 10) {
      final r = rumbo(ms);
      expect(r, greaterThanOrEqualTo(antes - 1e-9));
      expect(r, lessThanOrEqualTo(90 + 1e-9));
      antes = r;
    }
    expect(rumbo(BusMotion.giro.inMilliseconds), closeTo(90, 0.01));
    expect(BusMotion.giro, lessThan(BusMotion.minimo));
  });

  test('pasado el segundo el bus se queda en su destino', () {
    final start = DateTime(2024, 1, 1, 12, 0, 0);
    final m = BusMotion(
      fromLat: 10,
      fromLon: 20,
      fromHeading: 0,
      toLat: 20,
      toLon: 40,
      toHeading: 90,
      start: start,
    );
    final tarde = displayOf(m, start.add(const Duration(seconds: 3)));
    expect(tarde.$1, closeTo(20, 0.01));
    expect(tarde.$2, closeTo(40, 0.01));
    expect(tarde.$3, closeTo(90, 0.01));
  });

  // Con un GPS real llega una posición cada 5–15 s: un tramo de 1 s dejaba
  // el bus quieto el resto del intervalo y luego saltaba (AUD16-05). El
  // tramo dura lo que tardó la fijación, entre 1 y 15 s.
  group('tramoEntre', () {
    const s = 1000;
    test('dura lo que pasó entre las dos fijaciones', () {
      expect(
          BusMotion.tramoEntre(100 * s, 108 * s), const Duration(seconds: 8));
    });

    test('nunca menos de 1 s ni más de 15 s', () {
      expect(BusMotion.tramoEntre(100 * s, 100 * s + 300),
          const Duration(seconds: 1));
      expect(
          BusMotion.tramoEntre(100 * s, 400 * s), const Duration(seconds: 15));
    });

    test('sin las dos fechas, o con la nueva más vieja, 1 s', () {
      expect(BusMotion.tramoEntre(null, 108 * s), const Duration(seconds: 1));
      expect(BusMotion.tramoEntre(100 * s, null), const Duration(seconds: 1));
      expect(
          BusMotion.tramoEntre(108 * s, 100 * s), const Duration(seconds: 1));
    });

    test('un tramo de 8 s va por la mitad a los 4 s y acaba a los 8', () {
      final start = DateTime(2024, 1, 1, 12, 0, 0);
      final m = BusMotion(
        fromLat: 10,
        fromLon: 20,
        fromHeading: 0,
        toLat: 20,
        toLon: 40,
        toHeading: 0,
        start: start,
        duration: const Duration(seconds: 8),
      );
      expect(displayOf(m, start.add(const Duration(seconds: 4))).$1,
          closeTo(15, 0.01));
      expect(
          m.isFinished(start.add(const Duration(milliseconds: 7999))), isFalse);
      expect(m.isFinished(start.add(const Duration(seconds: 8))), isTrue);
    });
  });

  // El pasajero recibe `BusPosition`: manda la hora del equipo y, si falta
  // en alguna, la del servidor.
  group('tramoDe', () {
    BusPosition pos(int segundo, {int? capturedAt}) => BusPosition(
          busId: 'B',
          routeId: 'R',
          lat: 0,
          lon: 0,
          heading: null,
          speedKmh: 0,
          timestamp: DateTime.fromMillisecondsSinceEpoch(segundo * 1000),
          isGhostBus: false,
          capturedAt: capturedAt,
        );

    test('con la hora del equipo en las dos, esa', () {
      expect(
          BusMotion.tramoDe(
              pos(0, capturedAt: 1000), pos(12, capturedAt: 7000)),
          const Duration(seconds: 6));
    });

    test('si falta en alguna, la del servidor', () {
      expect(BusMotion.tramoDe(pos(0), pos(9, capturedAt: 7000)),
          const Duration(seconds: 9));
    });
  });
}
