import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

/// La ocupación de ejemplo de un bus: sube y baja por tramos a lo largo de
/// toda la ruta, y no igual en todos los buses (dueño, 2026-10-27).
void main() {
  final pico = DateTime(2026, 10, 27, 7, 15);
  final noche = DateTime(2026, 10, 27, 22, 30);

  List<int> recorrido(String bus, DateTime hora, {int pasos = 400}) => [
        for (var i = 0; i <= pasos; i++)
          ocupacionSimulada(
              busId: bus, routeId: 'R-001', tramo: i / pasos, hora: hora),
      ];

  test('va de 0 a 100 y es la misma para el mismo bus, tramo y hora', () {
    for (final pct in recorrido('BUS-SQA220', pico)) {
      expect(pct, inInclusiveRange(0, 100));
    }
    expect(recorrido('BUS-SQA220', pico), recorrido('BUS-SQA220', pico));
  });

  test('sube y baja varias veces a lo largo de la ruta', () {
    final pcts = recorrido('BUS-SQA220', pico);
    var subidas = 0, bajadas = 0;
    for (var i = 1; i < pcts.length; i++) {
      if (pcts[i] > pcts[i - 1] && (i == 1 || pcts[i - 1] <= pcts[i - 2])) {
        subidas++;
      }
      if (pcts[i] < pcts[i - 1] && (i == 1 || pcts[i - 1] >= pcts[i - 2])) {
        bajadas++;
      }
    }
    expect(subidas, greaterThanOrEqualTo(2));
    expect(bajadas, greaterThanOrEqualTo(2));
    final mayor = pcts.reduce((a, b) => a > b ? a : b);
    final menor = pcts.reduce((a, b) => a < b ? a : b);
    expect(mayor - menor, greaterThanOrEqualTo(30));
  });

  test('cambia poco a poco, sin saltos, y cierra la vuelta', () {
    final pcts = recorrido('BUS-SQA220', pico);
    for (var i = 1; i < pcts.length; i++) {
      expect((pcts[i] - pcts[i - 1]).abs(), lessThanOrEqualTo(3),
          reason: 'tramo ${i / 400}');
    }
    expect((pcts.first - pcts.last).abs(), lessThanOrEqualTo(1));
  });

  test('en un mismo tramo a un bus le sube y a otro le baja', () {
    final a = recorrido('BUS-SQA220', pico, pasos: 100);
    final b = recorrido('BUS-SQA221', pico, pasos: 100);
    var opuestos = 0;
    for (var i = 1; i < a.length; i++) {
      final da = a[i] - a[i - 1], db = b[i] - b[i - 1];
      if (da * db < 0) opuestos++;
    }
    expect(opuestos, greaterThanOrEqualTo(10));
  });

  test('en hora pico va más lleno que de noche', () {
    double promedio(List<int> l) => l.reduce((a, b) => a + b) / l.length;
    for (final bus in ['BUS-SQA220', 'BUS-SQA221', 'BUS-XKT455']) {
      expect(promedio(recorrido(bus, pico)),
          greaterThan(promedio(recorrido(bus, noche)) + 20));
    }
  });
}
