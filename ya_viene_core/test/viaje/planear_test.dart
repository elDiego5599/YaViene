// «Estoy aquí, voy allá»: qué ruta tomar, dónde subir y dónde bajar. Las
// rutas se dibujan en metros (dibujo.dart) y cada cifra sale del dibujo.
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

import 'dibujo.dart';

List<Viaje> _viajes(Plan plan) => switch (plan) {
      PlanConViajes(:final viajes) => viajes,
      _ => fail('se esperaban viajes y salió $plan'),
    };

void main() {
  group('un bus', () {
    final red = RedDeRutas([recta()]);

    test(
        'sube en el punto de la ruta más cerca del origen y baja en el '
        'más cerca del destino', () {
      final viaje =
          _viajes(planear(lugar(200, 50), lugar(1500, -80), red)).single;

      expect(viaje.buses, 1);
      final enBus = viaje.enBus.single;
      expect(enBus.ruta, 'RECTA');
      expect(enBus.empresa, 'EMP');
      expect(enBus.subida.avance, closeTo(200, 1));
      expect(enBus.subida.caminata, closeTo(50, 1));
      expect(enBus.bajada.avance, closeTo(1500, 1));
      expect(enBus.bajada.caminata, closeTo(80, 1));
      expect(enBus.metrosPorLaRuta, closeTo(1300, 1));
      expect(viaje.metrosEnBus, closeTo(1300, 1));
      expect(viaje.caminataTotal, closeTo(130, 1));
    });

    test('los tramos van del origen al destino: a pie, en bus y a pie', () {
      final origen = lugar(200, 50), destino = lugar(1500, -80);
      final viaje = _viajes(planear(origen, destino, red)).single;

      expect(viaje.origen, origen);
      expect(viaje.destino, destino);
      expect(viaje.tramos, [
        isA<TramoAPie>(),
        isA<TramoEnBus>(),
        isA<TramoAPie>(),
      ]);
      final ida = viaje.tramos.first as TramoAPie;
      final vuelta = viaje.tramos.last as TramoAPie;
      expect(ida.desde, origen.punto);
      expect(ida.hasta, viaje.enBus.single.subida.punto);
      expect(vuelta.desde, viaje.enBus.single.bajada.punto);
      expect(vuelta.hasta, destino.punto);
    });

    test('hacia atrás no hay viaje: el bus no se devuelve', () {
      expect(
          planear(lugar(1500, 50), lugar(200, -80), red), isA<PlanSinRuta>());
    });

    test('sin ruta, dice de cuál de los dos puntos pasa cerca alguna', () {
      PlanSinRuta sinRuta(Lugar origen, Lugar destino) =>
          planear(origen, destino, red) as PlanSinRuta;

      final atras = sinRuta(lugar(1500, 50), lugar(200, -80));
      expect(atras.pasaCercaDelOrigen, isTrue);
      expect(atras.pasaCercaDelDestino, isTrue);

      final origenLejos = sinRuta(lugar(200, 5000), lugar(1500, 0));
      expect(origenLejos.pasaCercaDelOrigen, isFalse);
      expect(origenLejos.pasaCercaDelDestino, isTrue);

      final destinoLejos = sinRuta(lugar(200, 0), lugar(1500, 5000));
      expect(destinoLejos.pasaCercaDelOrigen, isTrue);
      expect(destinoLejos.pasaCercaDelDestino, isFalse);
    });

    test('con el origen lejos de toda ruta no hay viaje', () {
      expect(
          planear(lugar(200, 5000), lugar(1500, 0), red), isA<PlanSinRuta>());
    });

    test('con el destino lejos de toda ruta no hay viaje', () {
      expect(
          planear(lugar(200, 0), lugar(1500, 5000), red), isA<PlanSinRuta>());
    });

    test('la caminata tiene tope: a 601 m de la ruta no se ofrece', () {
      expect(planear(lugar(200, 601), lugar(1500, 0), red), isA<PlanSinRuta>());
      expect(
          _viajes(planear(lugar(200, 599), lugar(1500, 0), red)), hasLength(1));
    });

    test('el tope de caminata es un parámetro', () {
      const corto = OpcionesDePlan(caminataMaxima: 100);
      expect(planear(lugar(200, 150), lugar(1500, 0), red, corto),
          isA<PlanSinRuta>());
    });
  });

  group('muy cerca para ir en bus', () {
    final red = RedDeRutas([recta()]);

    test('el mismo punto de origen y destino', () {
      final plan = planear(lugar(200, 0), lugar(200, 0), red);
      expect(plan, isA<PlanMuyCerca>());
      expect((plan as PlanMuyCerca).metros, closeTo(0, 1e-6));
    });

    test('a 250 m se llega antes a pie y dice cuántos metros son', () {
      final plan = planear(lugar(200, 0), lugar(450, 0), red);
      expect(plan, isA<PlanMuyCerca>());
      expect((plan as PlanMuyCerca).metros, closeTo(250, 1));
    });

    test('si el bus hace caminar más que ir derecho, se va a pie', () {
      // 500 m entre los dos puntos; por la ruta se caminarían 550 + 550.
      final plan = planear(lugar(1000, 550), lugar(1500, 550), red);
      expect(plan, isA<PlanMuyCerca>());
      expect((plan as PlanMuyCerca).metros, closeTo(500, 1));
    });
  });

  group('ida y vuelta por calles paralelas', () {
    final red = RedDeRutas([idaYVuelta()]);

    test('toma el carril que va hacia allá aunque el otro quede más cerca', () {
      // El origen está a 20 m de la ida y a 80 m de la vuelta; el destino
      // queda atrás. Por la ida habría que ir hasta el final y volver.
      final viaje =
          _viajes(planear(lugar(1500, 20), lugar(200, 60), red)).single;
      final enBus = viaje.enBus.single;

      expect(enBus.subida.caminata, closeTo(80, 1));
      expect(enBus.bajada.caminata, closeTo(40, 1));
      // Vuelta: 2.000 de ida + 100 de la esquina + lo andado hacia el oeste.
      expect(enBus.subida.avance, closeTo(2600, 1));
      expect(enBus.bajada.avance, closeTo(3900, 1));
      expect(enBus.metrosPorLaRuta, closeTo(1300, 1));
    });

    test('de ida sube por la ida', () {
      final enBus = _viajes(planear(lugar(200, 60), lugar(1500, 20), red))
          .single
          .enBus
          .single;
      expect(enBus.subida.avance, closeTo(200, 1));
      expect(enBus.bajada.avance, closeTo(1500, 1));
    });
  });

  group('circular', () {
    final red = RedDeRutas([circular()]);

    test('sigue el sentido de la ruta al doblar la esquina', () {
      final enBus = _viajes(planear(lugar(1000, 50), lugar(3050, 2000), red))
          .single
          .enBus
          .single;
      expect(enBus.metrosPorLaRuta, closeTo(4000, 1));
    });

    test('pasa por el inicio de la ruta sin cortar el viaje', () {
      // Sube bajando por x = 0, a 500 m del cierre, y baja 800 m después
      // del inicio.
      final enBus = _viajes(planear(lugar(-50, 500), lugar(800, -40), red))
          .single
          .enBus
          .single;
      expect(enBus.subida.avance, closeTo(11500, 1));
      expect(enBus.bajada.avance, closeTo(800, 1));
      expect(enBus.metrosPorLaRuta, closeTo(1300, 1));
    });

    test('no ofrece dar la vuelta entera para ir un poco atrás', () {
      // 1,5 km atrás por la misma calle serían 10,5 km en bus.
      expect(
          planear(lugar(2000, 50), lugar(500, -50), red), isA<PlanSinRuta>());
    });
  });

  group('dos buses', () {
    test('donde dos rutas se cruzan se cambia de bus', () {
      final red = RedDeRutas([recta(), cruce()]);
      final viaje =
          _viajes(planear(lugar(500, 30), lugar(2040, 1500), red)).single;

      expect(viaje.buses, 2);
      expect(viaje.tramos, [
        isA<TramoAPie>(),
        isA<TramoEnBus>(),
        isA<TramoAPie>(),
        isA<TramoEnBus>(),
        isA<TramoAPie>(),
      ]);
      final [primero, segundo] = viaje.enBus;
      expect(primero.ruta, 'RECTA');
      expect(primero.subida.avance, closeTo(500, 1));
      expect(primero.bajada.avance, closeTo(2000, 30));
      expect(segundo.ruta, 'CRUCE');
      expect(segundo.subida.avance, closeTo(2000, 30));
      expect(segundo.bajada.avance, closeTo(3500, 1));
      expect(viaje.metrosEnBus, closeTo(3000, 60));
      final cambio = viaje.tramos[2] as TramoAPie;
      expect(cambio.metros, lessThan(30));
      expect(cambio.desde, primero.bajada.punto);
      expect(cambio.hasta, segundo.subida.punto);
      expect(viaje.caminataTotal, closeTo(30 + cambio.metros + 40, 1));
    });

    test('el cambio va en el sentido de las dos rutas', () {
      // Del norte del cruce al este de la recta: se baja del cruce en
      // (2000, 0) y la recta sigue al este.
      final red = RedDeRutas([recta(), cruce()]);
      final viaje =
          _viajes(planear(lugar(2030, -1500), lugar(3500, 20), red)).single;
      expect([for (final t in viaje.enBus) t.ruta], ['CRUCE', 'RECTA']);

      // Al revés no se puede: habría que ir contra las dos.
      expect(planear(lugar(3500, 20), lugar(2030, -1500), red),
          isA<PlanSinRuta>());
    });

    test('dos rutas que corren juntas dan un solo viaje con cambio', () {
      // La recta no llega al destino y la junta no pasa por el origen: se
      // cambia en cualquier punto del tramo que comparten, una sola opción.
      final red = RedDeRutas([recta(), junta()]);
      final viaje =
          _viajes(planear(lugar(200, 20), lugar(3030, 2500), red)).single;

      expect([for (final t in viaje.enBus) t.ruta], ['RECTA', 'JUNTA']);
      expect((viaje.tramos[2] as TramoAPie).metros, closeTo(10, 1));
      // 800 m hasta donde empiezan a ir juntas, 2.000 juntas (en una o en
      // la otra) y 2.490 al norte.
      expect(viaje.metrosEnBus, closeTo(800 + 2000 + 2490, 60));
    });

    test('si las dos llevan directo, no se ofrece el cambio', () {
      final red = RedDeRutas([recta(), junta()]);
      final viajes = _viajes(planear(lugar(1200, 30), lugar(2800, -20), red));

      expect(viajes, hasLength(2));
      expect(viajes.every((v) => v.buses == 1), isTrue);
      expect({for (final v in viajes) v.enBus.single.ruta}, {'RECTA', 'JUNTA'});
    });

    test('el cambio no camina más de lo que la red permite', () {
      // Dos rectas paralelas a 200 m: con 150 m de tope no hay cambio.
      final lejos = ruta('LEJOS', [m(0, 200), m(3000, 200), m(3000, 3000)]);
      final red = RedDeRutas([recta(), lejos]);
      expect(planear(lugar(200, -500), lugar(3030, 2500), red),
          isA<PlanSinRuta>());

      final amplia = RedDeRutas([recta(), lejos], caminataDeTransbordo: 250);
      final viaje =
          _viajes(planear(lugar(200, -500), lugar(3030, 2500), amplia)).single;
      expect((viaje.tramos[2] as TramoAPie).metros, closeTo(200, 1));
    });

    test('sin transbordos en las opciones, solo directos', () {
      final red = RedDeRutas([recta(), cruce()]);
      expect(
        planear(lugar(500, 30), lugar(2040, 1500), red,
            const OpcionesDePlan(conTransbordo: false)),
        isA<PlanSinRuta>(),
      );
    });

    test('un cambio que camina menos que el directo se ofrece después de él',
        () {
      // La recta deja a 550 m del destino; el cruce, a 40 m.
      final red = RedDeRutas([recta(), cruce()]);
      final viajes = _viajes(planear(lugar(500, 30), lugar(2040, 550), red));

      expect([for (final v in viajes) v.buses], [1, 2]);
      expect(viajes.first.caminataTotal, closeTo(30 + 550, 2));
      expect(viajes.last.caminataTotal, lessThan(110));
    });

    test('un cambio por ahorrar 300 m a pie no vale la otra espera', () {
      // La recta deja a 350 m del destino; el cruce, a 40 m.
      final red = RedDeRutas([recta(), cruce()]);
      final viajes = _viajes(planear(lugar(500, 30), lugar(2040, 350), red));
      expect([for (final v in viajes) v.buses], [1]);
    });

    test('un cambio que camina lo mismo o más que un directo no se ofrece', () {
      final red = RedDeRutas([recta(), cruce()]);
      // El destino está sobre la recta: el cruce no ahorra nada.
      final viajes = _viajes(planear(lugar(500, 30), lugar(2500, 20), red));
      expect([for (final v in viajes) v.buses], [1]);
    });
  });

  group('orden', () {
    test('menos buses y, entre iguales, el que menos cuesta', () {
      // Tres paralelas hacia el este: a 20, 250 y 480 m del origen y del
      // destino. Y una cuarta, tan cerca como la primera, que da un rodeo.
      final rodeo = ruta('RODEO', [
        m(0, -20),
        m(1500, -20),
        m(1500, -900),
        m(1600, -900),
        m(1600, -20),
        m(4000, -20),
      ]);
      final red = RedDeRutas([
        ruta('LEJOS', [m(0, 480), m(4000, 480)]),
        rodeo,
        ruta('MEDIA', [m(0, 250), m(4000, 250)]),
        ruta('CERCA', [m(0, 20), m(4000, 20)]),
      ]);
      final viajes = _viajes(planear(lugar(500, 0), lugar(3000, 0), red));

      expect([for (final v in viajes) v.enBus.single.ruta],
          ['CERCA', 'RODEO', 'MEDIA']);
    });

    test('nunca más de tres opciones, y el tope es un parámetro', () {
      final red = RedDeRutas([
        for (var i = 0; i < 5; i++)
          ruta('R$i', [m(0, 100.0 * i), m(4000, 100.0 * i)]),
      ]);
      expect(
          _viajes(planear(lugar(500, 0), lugar(3000, 0), red)), hasLength(3));
      expect(
        _viajes(planear(lugar(500, 0), lugar(3000, 0), red,
            const OpcionesDePlan(maximo: 1))),
        hasLength(1),
      );
    });

    test('cien metros menos a pie no valen kilómetros de más en bus', () {
      // CERCA pasa a 50 m de cada punto pero da un rodeo de 3 km; DERECHA
      // pasa a 150 m y va derecho. Caminar pesa cuatro veces: 800 m de
      // más a pie contra 3.000 de más en bus.
      final cerca = ruta('CERCA', [
        m(0, 50),
        m(1500, 50),
        m(1500, 1550),
        m(1600, 1550),
        m(1600, 50),
        m(4000, 50),
      ]);
      final red = RedDeRutas([
        cerca,
        ruta('DERECHA', [m(0, -150), m(4000, -150)])
      ]);
      final viajes = _viajes(planear(lugar(500, 0), lugar(3000, 0), red));
      expect(
          [for (final v in viajes) v.enBus.single.ruta], ['DERECHA', 'CERCA']);
    });

    test('un viaje que cuesta más del doble que el mejor no se ofrece', () {
      // La vuelta larga pasa tan cerca como la recta, pero anda 7.300 m
      // para llegar a donde la recta llega en 2.500.
      final vueltaLarga = ruta('VUELTA', [
        m(0, 20),
        m(1500, 20),
        m(1500, 2420),
        m(1600, 2420),
        m(1600, 20),
        m(4000, 20),
      ]);
      final red = RedDeRutas([recta(), vueltaLarga]);
      final viajes = _viajes(planear(lugar(500, 0), lugar(3000, 0), red));
      expect([for (final v in viajes) v.enBus.single.ruta], ['RECTA']);

      // Sola, es lo que hay y se ofrece.
      final sola = _viajes(
          planear(lugar(500, 0), lugar(3000, 0), RedDeRutas([vueltaLarga])));
      expect(sola.single.enBus.single.ruta, 'VUELTA');
    });
  });

  group('propiedades', () {
    final red =
        RedDeRutas([recta(), cruce(), junta(), circular(), idaYVuelta()]);
    const opciones = OpcionesDePlan();
    final azar = math.Random(7);
    double coordenada() => -700 + azar.nextDouble() * 4400;

    test('en mil búsquedas al azar, ningún viaje rompe las reglas', () {
      var conViajes = 0;
      for (var i = 0; i < 1000; i++) {
        final origen = lugar(coordenada(), coordenada());
        final destino = lugar(coordenada(), coordenada());
        final plan = planear(origen, destino, red);
        if (plan is! PlanConViajes) continue;
        conViajes++;
        expect(plan.viajes, isNotEmpty);
        expect(plan.viajes.length, lessThanOrEqualTo(opciones.maximo));
        for (final viaje in plan.viajes) {
          expect(viaje.buses, inInclusiveRange(1, 2));
          expect(viaje.tramos.first, isA<TramoAPie>());
          expect(viaje.tramos.last, isA<TramoAPie>());
          for (final tramo in viaje.tramos) {
            switch (tramo) {
              case TramoAPie(:final metros):
                expect(metros, inInclusiveRange(0, opciones.caminataMaxima));
              case TramoEnBus(:final metrosPorLaRuta):
                expect(metrosPorLaRuta.isFinite, isTrue);
                expect(metrosPorLaRuta,
                    greaterThanOrEqualTo(opciones.tramoMinimo));
            }
          }
          // El bus ahorra caminata o no se ofrece.
          expect(
            viaje.caminataTotal,
            lessThan(haversineMeters(origen.punto.lat, origen.punto.lon,
                destino.punto.lat, destino.punto.lon)),
          );
        }
        // Ordenados: nunca un viaje de dos buses antes de uno de uno.
        final buses = [for (final v in plan.viajes) v.buses];
        expect(buses, [...buses]..sort());
      }
      // La prueba no pasa en vacío.
      expect(conViajes, greaterThan(100));
    });
  });
}
