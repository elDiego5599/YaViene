import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_pasajero/features/map/presentation/widgets/map_widget.dart';

/// «El botón que te lleva a tu pin no lo centra bien» (dueño, 2026-10-16).
/// El encuadre deja el pin en el hueco entre la barra de búsqueda y la
/// hoja. En iPhone el mapa ya suma por su cuenta lo que tapa la hoja (su
/// margen de contenido); en Android no.
void main() {
  test('en iPhone la hoja no cuenta dos veces', () {
    final r = rellenoDelEncuadre(hoja: 360, ios: true);
    expect(r.bottom, 32);
    expect(r.top, 148);
  });

  test('en Android el relleno es la hoja y su margen', () {
    expect(rellenoDelEncuadre(hoja: 360, ios: false).bottom, 360 + 32);
  });

  test('con la guía, el trozo que ella deja a la vista', () {
    const foco = Rect.fromLTRB(0, 200, 390, 600);
    final ios = rellenoDelEncuadre(hoja: 120, ios: true, foco: foco, alto: 844);
    expect(ios.top, 200);
    expect(ios.bottom, 844 - 600 - 120);
    expect(
        rellenoDelEncuadre(hoja: 120, ios: false, foco: foco, alto: 844).bottom,
        844 - 600);
  });

  // AUD29-04: al abrir hasta el bus más cercano la píldora «N buses cerca de
  // tu punto» sigue arriba; con 148 pt el bus quedaba debajo de ella.
  test('bajo la píldora, el borde de arriba la deja libre', () {
    final r = rellenoDelEncuadre(hoja: 360, ios: true, bajoLaPildora: true);
    expect(r.top, rellenoBajoLaPildora);
    expect(r.top, greaterThan(205));
    expect(r.bottom, 32);
    expect(rellenoDelEncuadre(hoja: 360, ios: true).top, 148);
  });
}
