import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_control/features/fleet/presentation/providers/ocupacion_provider.dart';
import 'package:ya_viene_control/features/fleet/presentation/providers/reportes_provider.dart';

// 11:30 p. m. del 26 de octubre en Bogotá: el día ya tiene todas sus horas.
final _noche = DateTime.utc(2026, 10, 27, 4, 30);

List<int?> _de(
  List<String> buses, {
  String ruta = 'B18',
  PeriodoReporte periodo = PeriodoReporte.hoy,
  DateTime? ahora,
}) => ocupacionEjemplo(
  routeId: ruta,
  buses: buses,
  periodo: periodo,
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
    expect(
      _de(buses, periodo: PeriodoReporte.delDia(DateTime(2026, 10, 26))),
      hoy,
    );
  });

  test('las horas de hoy que aún no llegan no tienen dato', () {
    // 1:30 p. m. en Bogotá: hasta la 1 hay viajes, de las 2 en adelante no.
    final tarde = DateTime.utc(2026, 10, 26, 18, 30);
    final horas = _de(['b1'], ahora: tarde);
    for (var h = 5; h <= 13; h++) {
      expect(horas[h - 5], isNotNull, reason: 'a las $h');
    }
    for (var h = 14; h <= 23; h++) {
      expect(horas[h - 5], isNull, reason: 'a las $h');
    }
    // Siete días atrás sí hay de todas las horas.
    expect(
      _de(['b1'], periodo: PeriodoReporte.semana, ahora: tarde),
      everyElement(isNotNull),
    );
  });

  test('una ruta sin buses no tiene ocupación', () {
    expect(_de(const []), everyElement(isNull));
  });
}
