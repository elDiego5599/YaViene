import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_control/features/fleet/presentation/providers/ocupacion_provider.dart';
import 'package:ya_viene_control/features/fleet/presentation/providers/reportes_provider.dart';

// 12:30 a. m. del 27 de octubre en Bogotá: el 26 ya tiene todas sus horas,
// también la de 11 a 12, que solo cuenta al terminar.
final _noche = DateTime.utc(2026, 10, 27, 5, 30);
final _dia26 = PeriodoReporte.delDia(DateTime(2026, 10, 26));

List<int?> _de(
  List<String> buses, {
  String ruta = 'B18',
  PeriodoReporte? periodo,
  DateTime? ahora,
}) => ocupacionEjemplo(
  routeId: ruta,
  buses: buses,
  periodo: periodo ?? _dia26,
  ahora: ahora ?? _noche,
);

void main() {
  test('una barra por hora de servicio, de 5 a. m. a 11 p. m., en 0 a 100', () {
    final horas = _de(['b1', 'b2', 'b3']);
    expect(horas, hasLength(19));
    for (final pct in horas) {
      expect(pct, inInclusiveRange(0, 100));
    }
    expect(_de(['b1', 'b2', 'b3']), horas, reason: 'siempre la misma');
  });

  test('la ruta es el promedio de sus buses', () {
    final uno = _de(['b1']);
    final otro = _de(['b2']);
    expect(uno, isNot(otro), reason: 'cada bus lleva lo suyo');
    final juntos = _de(['b1', 'b2']);
    for (var i = 0; i < 19; i++) {
      expect(juntos[i], ((uno[i]! + otro[i]!) / 2).round());
    }
  });

  test('cambia con la ruta y con el periodo', () {
    const buses = ['b1', 'b2'];
    expect(_de(buses, ruta: 'C11'), isNot(_de(buses)));
    final hoy = _de(buses);
    final semana = _de(buses, periodo: PeriodoReporte.semana);
    final mes = _de(buses, periodo: PeriodoReporte.mes);
    expect(semana, isNot(hoy));
    expect(mes, isNot(semana));
    // Un día del calendario es ese día y no otro.
    final ayer = _de(
      buses,
      periodo: PeriodoReporte.delDia(DateTime(2026, 10, 25)),
    );
    expect(ayer, isNot(hoy));
    // Hoy es el día del calendario de hoy, cortado en este momento.
    final tarde = DateTime.utc(2026, 10, 26, 22, 30);
    expect(
      _de(buses, periodo: PeriodoReporte.hoy, ahora: tarde),
      _de(buses, ahora: tarde),
    );
  });

  test('una hora solo tiene dato cuando ya terminó', () {
    // 1:30 p. m. en Bogotá: de 12 a 1 ya pasó; de 1 a 2 aún no termina.
    final tarde = DateTime.utc(2026, 10, 26, 18, 30);
    final horas = _de(['b1'], periodo: PeriodoReporte.hoy, ahora: tarde);
    for (var h = 5; h <= 12; h++) {
      expect(horas[h - 5], isNotNull, reason: 'a las $h');
    }
    for (var h = 13; h <= 23; h++) {
      expect(horas[h - 5], isNull, reason: 'a las $h');
    }
    // Siete días atrás sí hay de todas las horas.
    expect(
      _de(['b1'], periodo: PeriodoReporte.semana, ahora: tarde),
      everyElement(isNotNull),
    );
  });

  test('cada ruta tiene su forma, con lo más lleno en hora pico', () {
    const rutas = ['B18', 'C11', 'A4', 'D8', 'R-101', 'R-105'];
    final formas = {
      for (final r in rutas)
        r: () {
          final h = _de(
            ['b1', 'b2', 'b3'],
            ruta: r,
            periodo: PeriodoReporte.mes,
          );
          final tope = h.map((v) => v!).reduce((a, b) => a > b ? a : b);
          return [for (final v in h) v! / tope];
        }(),
    };
    for (final r in rutas) {
      final f = formas[r]!;
      final pico = f.indexOf(1.0) + primeraHoraServicio;
      expect(
        (pico >= 6 && pico <= 8) || (pico >= 16 && pico <= 19),
        isTrue,
        reason: '$r llena a las $pico',
      );
    }
    // No es la misma curva escalada: entre dos rutas cualesquiera alguna
    // hora cambia al menos 12 puntos de su máximo.
    for (var i = 0; i < rutas.length; i++) {
      for (var j = i + 1; j < rutas.length; j++) {
        final a = formas[rutas[i]]!, b = formas[rutas[j]]!;
        var mayor = 0.0;
        for (var k = 0; k < a.length; k++) {
          mayor = (a[k] - b[k]).abs() > mayor ? (a[k] - b[k]).abs() : mayor;
        }
        expect(
          mayor,
          greaterThanOrEqualTo(0.12),
          reason: '${rutas[i]} y ${rutas[j]}',
        );
      }
    }
  });

  test('una ruta sin buses no tiene ocupación', () {
    expect(_de(const []), everyElement(isNull));
  });
}
