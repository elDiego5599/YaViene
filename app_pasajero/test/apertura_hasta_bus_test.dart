import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_pasajero/features/map/presentation/utils/apertura_hasta_bus.dart';

/// AUD29-04: tras «Ver buses en vivo» el bus más cercano tiene que quedar a
/// la vista. El encuadre no se gasta con el selector abierto y se rehace si
/// la hoja cambia de alto, hasta que el dedo toca el mapa.
void main() {
  const libre = (selectorAbierto: false, busElegido: false, hayBuses: true);

  test('sin ruta elegida no abre nada', () {
    final a = AperturaHastaBus();
    expect(a.alLote(libre), isFalse);
    expect(a.alMargen(libre), isFalse);
  });

  test('con el selector abierto espera y abre al cerrarse', () {
    final a = AperturaHastaBus()..rutaElegida();
    expect(a.alLote((selectorAbierto: true, busElegido: false, hayBuses: true)),
        isFalse);
    expect(a.alCerrarSelector(libre), isTrue);
    expect(a.alLote(libre), isFalse, reason: 'un lote más no la repite');
  });

  test('sin buses todavía, espera al primer lote', () {
    final a = AperturaHastaBus()..rutaElegida();
    expect(
        a.alCerrarSelector(
            (selectorAbierto: false, busElegido: false, hayBuses: false)),
        isFalse);
    expect(a.alLote(libre), isTrue);
  });

  test('si la hoja cambia de alto después, se rehace', () {
    final a = AperturaHastaBus()..rutaElegida();
    expect(a.alLote(libre), isTrue);
    expect(a.alMargen(libre), isTrue);
    expect(a.alMargen(libre), isTrue);
  });

  test('el dedo en el mapa la suelta', () {
    final a = AperturaHastaBus()..rutaElegida();
    expect(a.alLote(libre), isTrue);
    a.dedo();
    expect(a.alMargen(libre), isFalse);
    expect(a.alLote(libre), isFalse);
  });

  test('el dedo antes del primer lote también la cancela', () {
    final a = AperturaHastaBus()
      ..rutaElegida()
      ..dedo();
    expect(a.alLote(libre), isFalse);
  });

  test('con un bus elegido no se mueve', () {
    final a = AperturaHastaBus()..rutaElegida();
    expect(a.alLote((selectorAbierto: false, busElegido: true, hayBuses: true)),
        isFalse);
  });

  test('otra ruta vuelve a empezar', () {
    final a = AperturaHastaBus()..rutaElegida();
    expect(a.alLote(libre), isTrue);
    a.rutaElegida();
    expect(a.alMargen(libre), isFalse, reason: 'aún no hay lote nuevo');
    expect(a.alLote(libre), isTrue);
  });
}
