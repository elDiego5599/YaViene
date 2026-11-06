import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_pasajero/features/map/presentation/utils/apertura_hasta_bus.dart';

/// AUD29-04: tras «Ver buses en vivo» el bus más cercano tiene que quedar a
/// la vista. El encuadre no se gasta con el selector abierto y se rehace si
/// la hoja cambia de alto, hasta que el dedo toca el mapa.
///
/// «Se mueve a 2 lados y luego se queda quieto» (dueño, 2026-11-06): el
/// cierre del selector, el salto del pin a la ruta nueva, la hoja que cambia
/// de alto y el primer lote movían la cámara cada uno por su lado, 800 ms
/// cada vez, pisándose. Ahora todos piden y la cámara se mueve una vez,
/// cuando la pantalla se calma.
void main() {
  late MomentoDelMapa momento;
  late int encuadres;
  late AperturaHastaBus a;

  setUp(() {
    momento = (selectorAbierto: false, busElegido: false, hayBuses: true);
    encuadres = 0;
    a = AperturaHastaBus(momento: () => momento, encuadrar: () => encuadres++);
  });
  tearDown(() => a.dispose());

  // Lo que tarda la pantalla en calmarse, y un poco más.
  Future<void> calma(WidgetTester t) =>
      t.pump(AperturaHastaBus.calma + const Duration(milliseconds: 1));

  testWidgets('sin ruta elegida no abre nada', (t) async {
    a
      ..lote()
      ..cambio();
    await calma(t);
    expect(encuadres, 0);
  });

  testWidgets('elegir la ruta encuadra una sola vez, ya calmada', (t) async {
    a.rutaElegida();
    await t.pump(AperturaHastaBus.calma ~/ 2);
    expect(encuadres, 0, reason: 'todavía hay cosas moviéndose');
    await calma(t);
    expect(encuadres, 1);
  });

  testWidgets('el cierre, el pin, la hoja y el lote se juntan en un encuadre',
      (t) async {
    momento = (selectorAbierto: true, busElegido: false, hayBuses: false);
    a.rutaElegida();
    await calma(t);
    expect(encuadres, 0, reason: 'con el selector encima no se gasta');

    momento = (selectorAbierto: false, busElegido: false, hayBuses: false);
    a.cambio(); // se cierra el selector
    await t.pump(const Duration(milliseconds: 100));
    a.cambio(); // el pin salta a la ruta nueva
    await t.pump(const Duration(milliseconds: 100));
    momento = (selectorAbierto: false, busElegido: false, hayBuses: true);
    a.lote(); // llegan los buses
    await t.pump(const Duration(milliseconds: 100));
    a.cambio(); // la hoja crece con la lista
    await calma(t);
    expect(encuadres, 1);
  });

  testWidgets('sin buses encuadra el pin y vuelve con el primer lote',
      (t) async {
    momento = (selectorAbierto: false, busElegido: false, hayBuses: false);
    a.rutaElegida();
    await calma(t);
    expect(encuadres, 1, reason: 'el pin solo, sin esperar a nadie');
    momento = (selectorAbierto: false, busElegido: false, hayBuses: true);
    a.lote();
    await calma(t);
    expect(encuadres, 2, reason: 'ahora con el bus más cercano');
    a.lote();
    await calma(t);
    expect(encuadres, 2, reason: 'un lote más no la repite');
  });

  testWidgets('si la hoja cambia de alto después, se rehace', (t) async {
    a.rutaElegida();
    await calma(t);
    a.cambio();
    await calma(t);
    expect(encuadres, 2);
  });

  testWidgets('el dedo en el mapa la suelta', (t) async {
    a.rutaElegida();
    await calma(t);
    a
      ..dedo()
      ..cambio()
      ..lote();
    await calma(t);
    expect(encuadres, 1);
  });

  testWidgets('el dedo con el encuadre en espera lo cancela', (t) async {
    a.rutaElegida();
    await t.pump(AperturaHastaBus.calma ~/ 2);
    a.dedo();
    await calma(t);
    expect(encuadres, 0);
  });

  testWidgets('con un bus elegido no se mueve', (t) async {
    momento = (selectorAbierto: false, busElegido: true, hayBuses: true);
    a.rutaElegida();
    await calma(t);
    expect(encuadres, 0);
  });

  testWidgets('otra ruta vuelve a empezar', (t) async {
    a.rutaElegida();
    await calma(t);
    a.rutaElegida();
    await calma(t);
    expect(encuadres, 2);
  });

  testWidgets('cerrada la pantalla, el encuadre en espera no corre', (t) async {
    a
      ..rutaElegida()
      ..dispose();
    await calma(t);
    expect(encuadres, 0);
  });
}
