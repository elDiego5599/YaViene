// Los bordes exactos de cómo se escribe una distancia. El glosario prueba
// las reglas con cifras redondas; aquí van las que caen justo en la raya,
// donde una cifra cruda y una redondeada dicen cosas distintas: 999,6 m se
// escribían «1000 m» y 9.960 m «10,0 km».
import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import 'package:ya_viene_pasajero/core/utils/distancia.dart';
import 'package:ya_viene_pasajero/features/map/presentation/widgets/eta_bottom_sheet.dart';

void main() {
  test('en metros solo si, redondeados, no llegan a 1000', () {
    expect(enMetros(999.4), isTrue);
    expect(enMetros(999.6), isFalse);
    expect(enMetros(1000), isFalse);
    expect(distanciaAviso(999), '999 m');
    expect(distanciaAviso(1000), '1,0 km');
  });

  test('la cifra grande de la hoja cambia de unidad con el redondeo', () {
    expect(distanciaPartes(999.4, 'de ti'), ('999', 'm de ti'));
    expect(distanciaPartes(999.6, 'de ti'), ('1,0', 'km de ti'));
    // La hoja conserva el decimal pasados 10 km.
    expect(distanciaPartes(12340, 'de ti'), ('12,3', 'km de ti'));
  });

  test('sin decimal desde 10 km, contados ya redondeados', () {
    expect(kmLabel(9949), '9,9 km');
    expect(kmLabel(9960), '10 km');
    expect(kmLabel(10000), '10 km');
    expect(kmLabel(3400), '3,4 km');
  });

  test('la voz dice «metro» en singular solo para uno', () {
    expect(distanciaHablada(1, 'de ti'), 'A 1 metro de ti');
    expect(distanciaHablada(2, 'de ti'), 'A 2 metros de ti');
    expect(distanciaHablada(999.6, 'de ti'), 'A 1,0 kilómetros de ti');
  });

  test('el color de la cifra cambia justo en 300 m y en el radio', () {
    expect(colorDeDistancia(299.9), AppColors.coralAccessible);
    expect(colorDeDistancia(300), AppColors.warningAccessible);
    expect(colorDeDistancia(999.9), AppColors.warningAccessible);
    expect(colorDeDistancia(1000), AppColors.primaryAccessible);
  });
}
