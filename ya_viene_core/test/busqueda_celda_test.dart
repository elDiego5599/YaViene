import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_core/core/geo/celda_busqueda.dart';

void main() {
  test('redondea al centro de la rejilla, también con coordenadas negativas',
      () {
    expect(
        centroCeldaBusqueda(11.0048, -74.8078), (lat: 11.0052, lng: -74.80748));
    // JavaScript Math.round(-0.5) gives -0; Dart num.round() gives -1.
    expect(centroCeldaBusqueda(-0.000675, -0.000685), (lat: 0, lng: 0));
  });
}
