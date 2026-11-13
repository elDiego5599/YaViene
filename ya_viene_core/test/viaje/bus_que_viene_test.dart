// Qué bus en vivo viene hacia donde se sube, y cuánto le falta por la ruta.
import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

import 'dibujo.dart';

TramoEnBus _tramo(RedDeRutas red, Lugar origen, Lugar destino) =>
    (planear(origen, destino, red) as PlanConViajes).viajes.first.enBus.first;

void main() {
  group('en una ruta que no vuelve a empezar', () {
    final red = RedDeRutas([recta()]);
    final tramo = _tramo(red, lugar(1000, 0), lugar(3000, 0));
    SeguidorRuta seguidor() => SeguidorRuta(red.rutas.single.medible);

    test('el bus que viene es el más cerca antes de la subida', () {
      final viene = busQueViene(
        tramo,
        [bus('LEJOS', 'RECTA', 100, 0), bus('CERCA', 'RECTA', 700, 0)],
        seguidor(),
      )!;
      expect(viene.busId, 'CERCA');
      expect(viene.metrosHastaLaSubida, closeTo(300, 1));
      expect(viene.alDia, isTrue);
    });

    test('un bus justo en la subida viene a cero metros', () {
      final viene =
          busQueViene(tramo, [bus('AQUI', 'RECTA', 1000, 0)], seguidor())!;
      expect(viene.metrosHastaLaSubida, closeTo(0, 1));
    });

    test('un bus parado en la subida, con el GPS unos metros adelante, está',
        () {
      final viene =
          busQueViene(tramo, [bus('AQUI', 'RECTA', 1015, 0)], seguidor())!;
      expect(viene.metrosHastaLaSubida, 0);
    });

    test('un bus que ya pasó la subida no viene: no se devuelve', () {
      expect(busQueViene(tramo, [bus('PASO', 'RECTA', 1050, 0)], seguidor()),
          isNull);
    });

    test('sin buses no viene ninguno', () {
      expect(busQueViene(tramo, const [], seguidor()), isNull);
    });

    test('los buses de otra ruta no cuentan', () {
      expect(busQueViene(tramo, [bus('OTRO', 'OTRA', 700, 0)], seguidor()),
          isNull);
    });

    test('un bus fuera de la ruta no cuenta', () {
      expect(busQueViene(tramo, [bus('LEJOS', 'RECTA', 700, 500)], seguidor()),
          isNull);
    });

    test('un bus sin señal solo se ofrece si no hay otro, y lo dice', () {
      final sinSenal = bus('MUDO', 'RECTA', 900, 0, sinSenal: true);
      final conSenal = bus('VIVO', 'RECTA', 300, 0);

      expect(
          busQueViene(tramo, [sinSenal, conSenal], seguidor())!.busId, 'VIVO');
      final solo = busQueViene(tramo, [sinSenal], seguidor())!;
      expect(solo.busId, 'MUDO');
      expect(solo.alDia, isFalse);
    });
  });

  group('en una ruta circular', () {
    final red = RedDeRutas([circular()]);
    final tramo = _tramo(red, lugar(1000, 0), lugar(3000, 2000));
    SeguidorRuta seguidor() => SeguidorRuta(red.rutas.single.medible);

    test('el bus parado en la subida no dice que le falta la vuelta entera',
        () {
      final viene =
          busQueViene(tramo, [bus('AQUI', 'CIRCULAR', 1015, 0)], seguidor())!;
      expect(viene.metrosHastaLaSubida, 0);
    });

    test('el bus recién pasado viene, pero dando la vuelta entera', () {
      final viene =
          busQueViene(tramo, [bus('PASO', 'CIRCULAR', 1100, 0)], seguidor())!;
      expect(viene.metrosHastaLaSubida, closeTo(12000 - 100, 1));
    });

    test(
        'el que viene por detrás del cierre está más cerca que el que '
        'acaba de pasar', () {
      final viene = busQueViene(
        tramo,
        [bus('PASO', 'CIRCULAR', 1100, 0), bus('VIENE', 'CIRCULAR', 0, 600)],
        seguidor(),
      )!;
      expect(viene.busId, 'VIENE');
      expect(viene.metrosHastaLaSubida, closeTo(600 + 1000, 1));
    });
  });
}
