// El modo guiado: de dónde está el teléfono y por dónde van los buses sale
// en qué parte del viaje va la persona. Cada lectura es una posición; nunca
// un reloj. Las rutas se dibujan en metros (dibujo.dart).
import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

import 'dibujo.dart';

Viaje _viaje(Lugar origen, Lugar destino, List<RutaDeLaRed> rutas) =>
    switch (planear(origen, destino, RedDeRutas(rutas))) {
      PlanConViajes(:final viajes) => viajes.first,
      final plan => fail('se esperaba un viaje y salió $plan'),
    };

GuiaDeViaje _guia(Viaje viaje, List<RutaDeLaRed> rutas) => GuiaDeViaje(
      viaje,
      seguidores: [
        for (final tramo in viaje.enBus)
          SeguidorRuta(rutas.firstWhere((r) => r.id == tramo.ruta).medible),
      ],
    );

void main() {
  // Sale de (1000, 200), sube en (1000, 0), anda 2 km al este, baja en
  // (3000, 0) y camina 150 m al sur.
  final rutas = [recta()];
  late GuiaDeViaje guia;
  setUp(() {
    guia = _guia(_viaje(lugar(1000, 200), lugar(3000, -150), rutas), rutas);
  });

  /// Sube al bus en (1000, 0) y va con él hasta [x], de 100 en 100 m.
  FaseDelViaje enElBusHasta(double x) {
    var segundos = 0;
    FaseDelViaje en(double paso) => guia.leer(
          telefono: m(paso, 0),
          buses: [bus('B1', 'RECTA', paso - 20, 0, segundos: segundos++)],
        );
    for (var paso = 1000.0; paso < x; paso += 100) {
      en(paso);
    }
    return en(x);
  }

  group('hasta la subida', () {
    test('sin la ubicación del teléfono no se guía', () {
      expect(guia.leer(telefono: null), const SinUbicacion());
    });

    test('lejos de donde se sube, dice lo que falta caminar y qué bus viene',
        () {
      final fase = guia.leer(
        telefono: m(1000, 200),
        buses: [bus('B1', 'RECTA', 400, 0)],
      );

      expect(
        fase,
        isA<CaminaALaSubida>()
            .having((f) => f.metros, 'metros', closeTo(200, 1))
            .having((f) => f.bus?.busId, 'bus', 'B1')
            .having(
                (f) => f.bus?.metrosHastaLaSubida, 'le falta', closeTo(600, 1)),
      );
    });

    test('en la subida, espera el bus que viene', () {
      final fase = guia.leer(
        telefono: m(1010, 20),
        buses: [bus('B1', 'RECTA', 400, 0)],
      );

      expect(
        fase,
        isA<EsperaElBus>().having(
            (f) => f.bus?.metrosHastaLaSubida, 'le falta', closeTo(600, 1)),
      );
    });

    test('sin buses en la ruta, espera sin bus', () {
      expect(guia.leer(telefono: m(1000, 10)), const EsperaElBus(bus: null));
    });

    test('un bus sin señal se dice que no está al día', () {
      final fase = guia.leer(
        telefono: m(1000, 10),
        buses: [bus('B1', 'RECTA', 900, 0, sinSenal: true)],
      );

      // Ni a 100 m se le dice «súbete»: esa posición es vieja.
      expect(fase,
          isA<EsperaElBus>().having((f) => f.bus?.alDia, 'al día', isFalse));
    });

    test('con el bus a 150 m o menos, súbete', () {
      expect(
        guia.leer(telefono: m(1000, 10), buses: [bus('B1', 'RECTA', 840, 0)]),
        isA<EsperaElBus>(),
      );
      expect(
        guia.leer(telefono: m(1000, 10), buses: [bus('B2', 'RECTA', 860, 0)]),
        isA<Subete>().having((f) => f.bus.busId, 'bus', 'B2'),
      );
    });

    test('caminando todavía no se le dice que se suba', () {
      final fase = guia.leer(
        telefono: m(1000, 120),
        buses: [bus('B1', 'RECTA', 900, 0)],
      );

      expect(
        fase,
        isA<CaminaALaSubida>().having(
            (f) => f.bus?.metrosHastaLaSubida, 'le falta', closeTo(100, 1)),
      );
    });

    test('un paso atrás en la esquina no lo devuelve a caminar', () {
      expect(guia.leer(telefono: m(1000, 30)), isA<EsperaElBus>());
      // El GPS baila: a 60 m sigue esperando; a 100 m ya se fue.
      expect(guia.leer(telefono: m(1000, 60)), isA<EsperaElBus>());
      expect(guia.leer(telefono: m(1000, 100)), isA<CaminaALaSubida>());
    });
  });

  group('subirse', () {
    test('avanzar por la ruta junto a un bus es ir en él', () {
      guia.leer(telefono: m(1000, 5), buses: [bus('B1', 'RECTA', 990, 0)]);
      final fase = guia.leer(
        telefono: m(1130, 0),
        buses: [bus('B1', 'RECTA', 1100, 0, segundos: 10)],
      );

      expect(
        fase,
        isA<EnElBus>()
            .having((f) => f.metrosParaBajar, 'falta', closeTo(1870, 1)),
      );
    });

    test('un bus que pasa junto a quien espera no se lo lleva', () {
      // El teléfono está 50 m más allá de la subida, en la esquina.
      final fase = guia.leer(
        telefono: m(1050, 10),
        buses: [bus('B1', 'RECTA', 1060, 0)],
      );

      expect(fase, isNot(isA<EnElBus>()));
    });

    test('caminar 200 m por la ruta sin un bus al lado no es ir en bus', () {
      guia.leer(telefono: m(1000, 5));
      expect(guia.leer(telefono: m(1200, 5)), isA<EsperaElBus>());
    });

    test('sin señal del bus, 300 m por la ruta ya es ir en él', () {
      guia.leer(telefono: m(1000, 5));
      final fase = guia.leer(
        telefono: m(1310, 0),
        buses: [bus('B1', 'RECTA', 700, 0, sinSenal: true)],
      );

      expect(
        fase,
        isA<EnElBus>()
            .having((f) => f.metrosParaBajar, 'falta', closeTo(1690, 1)),
      );
    });

    test('quien se sube antes de la subida va en el bus al pasarla', () {
      guia.leer(telefono: m(800, 0), buses: [bus('B1', 'RECTA', 790, 0)]);
      final fase = guia.leer(
        telefono: m(1150, 0),
        buses: [bus('B1', 'RECTA', 1140, 0, segundos: 30)],
      );

      expect(fase, isA<EnElBus>());
    });

    test('abre la app ya en el bus, lejos de la subida, y va en él', () {
      final fase = guia.leer(
        telefono: m(2200, 0),
        buses: [bus('B1', 'RECTA', 2190, 0)],
      );

      expect(
        fase,
        isA<EnElBus>()
            .having((f) => f.metrosParaBajar, 'falta', closeTo(800, 1)),
      );
    });
  });

  group('en el bus', () {
    test('dice lo que falta para bajarse', () {
      expect(
        enElBusHasta(2500),
        isA<EnElBus>()
            .having((f) => f.metrosParaBajar, 'falta', closeTo(500, 1)),
      );
    });

    test('a 400 m o menos, bájate en la próxima', () {
      expect(
        enElBusHasta(2610),
        isA<BajateEnLaProxima>()
            .having((f) => f.metros, 'falta', closeTo(390, 1)),
      );
    });

    test('ya avisado, un salto atrás del GPS no desdice el aviso', () {
      enElBusHasta(2610);

      expect(
        guia.leer(telefono: m(2580, 0)),
        isA<BajateEnLaProxima>()
            .having((f) => f.metros, 'falta', closeTo(420, 1)),
      );
    });

    test('sin ubicación a mitad del viaje lo dice, y al volver sigue', () {
      enElBusHasta(2000);

      expect(guia.leer(telefono: null), const SinUbicacion());
      expect(guia.leer(telefono: m(2300, 0)), isA<EnElBus>());
    });

    test('si el bus se sale de la ruta, no se manda a nadie a caminar', () {
      enElBusHasta(2000);

      // Un desvío por obra, 200 m al norte: faltan 1.059 m en línea recta.
      expect(
        guia.leer(telefono: m(2000, 200)),
        isA<FueraDeLaRuta>()
            .having((f) => f.metros, 'al destino', closeTo(1059, 2)),
      );
      // Y al volver a la ruta sigue el viaje.
      expect(
        guia.leer(telefono: m(2400, 0)),
        isA<EnElBus>()
            .having((f) => f.metrosParaBajar, 'falta', closeTo(600, 1)),
      );
    });
  });

  group('bajarse', () {
    test('en la bajada, camina a tu destino', () {
      expect(
        enElBusHasta(2980),
        isA<CaminaAlDestino>()
            .having((f) => f.metros, 'a pie', closeTo(151, 2)),
      );
    });

    test('quien se baja una cuadra antes también camina a su destino', () {
      enElBusHasta(2700);

      // A 100 m de la ruta, hacia el destino.
      expect(
        guia.leer(telefono: m(2750, -100)),
        isA<CaminaAlDestino>()
            .having((f) => f.metros, 'a pie', closeTo(255, 2)),
      );
    });

    test('a 40 m del destino, llegaste, y ahí se queda', () {
      enElBusHasta(3000);

      expect(guia.leer(telefono: m(3000, -80)), isA<CaminaAlDestino>());
      expect(guia.leer(telefono: m(3000, -120)), const Llegaste());
      expect(guia.leer(telefono: m(3000, 300)), const Llegaste());
      expect(guia.leer(telefono: null), const Llegaste());
    });

    test('150 m más allá de la bajada, todavía en la ruta, te pasaste', () {
      expect(enElBusHasta(3100), isA<CaminaAlDestino>());
      expect(
        guia.leer(telefono: m(3200, 0)),
        // De (3200, 0) a (3000, -150) hay 250 m.
        isA<TePasaste>().having((f) => f.metros, 'al destino', closeTo(250, 2)),
      );
    });

    test('quien se pasó y se devuelve a pie vuelve a caminar a su destino', () {
      enElBusHasta(3300);

      expect(guia.leer(telefono: m(3260, 0)), isA<TePasaste>());
      expect(guia.leer(telefono: m(3220, -70)), isA<CaminaAlDestino>());
      expect(guia.leer(telefono: m(3100, -20)), isA<CaminaAlDestino>());
    });
  });

  group('ruta circular', () {
    test('el tramo que cruza el inicio de la ruta se cuenta de corrido', () {
      // Sube en (0, 2000), baja al sur por x = 0, cierra la vuelta en el
      // origen y sigue 1,5 km al este: 3,5 km.
      final rutas = [circular()];
      final viaje = _viaje(lugar(-100, 2000), lugar(1500, -100), rutas);
      expect(viaje.enBus.single.metrosPorLaRuta, closeTo(3500, 1));
      final guia = _guia(viaje, rutas);

      expect(guia.leer(telefono: m(-20, 2000)), isA<EsperaElBus>());
      expect(
        guia.leer(
          telefono: m(0, 1000),
          buses: [bus('B1', 'CIRCULAR', 0, 1010)],
        ),
        isA<EnElBus>()
            .having((f) => f.metrosParaBajar, 'falta', closeTo(2500, 1)),
      );
      expect(
        guia.leer(telefono: m(700, 0)),
        isA<EnElBus>()
            .having((f) => f.metrosParaBajar, 'falta', closeTo(800, 1)),
      );
      expect(guia.leer(telefono: m(1480, 0)), isA<CaminaAlDestino>());
    });
  });

  group('dos buses', () {
    // RECTA de (500, 0) a (2000, 0) y CRUCE de ahí al norte hasta
    // (2000, 1500); el destino queda 40 m al este.
    final rutas = [recta(), cruce()];
    late Viaje viaje;
    late GuiaDeViaje guia;
    setUp(() {
      viaje = _viaje(lugar(500, 30), lugar(2040, 1500), rutas);
      guia = _guia(viaje, rutas);
    });

    void enLaRectaHasta(double x) {
      var segundos = 0;
      for (var paso = 500.0; paso <= x; paso += 100) {
        guia.leer(
          telefono: m(paso, 0),
          buses: [bus('B1', 'RECTA', paso - 20, 0, segundos: segundos++)],
        );
      }
    }

    test('se guía el primer bus', () {
      expect(guia.tramo.ruta, 'RECTA');
      expect(guia.leer(telefono: m(500, 20)), isA<EsperaElBus>());
    });

    test('al bajarse del primero, cambia de bus y dice cuál sigue', () {
      enLaRectaHasta(1900);

      expect(
        guia.leer(telefono: m(1990, 0)),
        isA<CambiaDeBus>()
            .having((f) => f.siguiente, 'sigue', viaje.enBus.last)
            .having((f) => f.metros, 'a pie', lessThan(40)),
      );
    });

    test('junto al destino del primer tramo no ha llegado', () {
      enLaRectaHasta(1900);

      expect(guia.leer(telefono: m(2000, 5)), isA<CambiaDeBus>());
    });

    test('el segundo bus no se guía solo: hay que pedirlo', () {
      enLaRectaHasta(1900);
      guia.leer(telefono: m(2000, 0));

      // Se sube al segundo sin tocar nada: la guía sigue en el cambio.
      final fase = guia.leer(
        telefono: m(2000, 600),
        buses: [bus('C1', 'CRUCE', 2000, 590)],
      );
      expect(fase, isA<CambiaDeBus>());
      expect(guia.tramo.ruta, 'RECTA');
    });

    test('pedido el segundo, se guía igual que el primero hasta llegar', () {
      enLaRectaHasta(1900);
      guia.leer(telefono: m(2000, 0));

      guia.tomarElSiguienteBus();

      expect(guia.tramo.ruta, 'CRUCE');
      expect(
        guia.leer(
          telefono: m(2000, 10),
          buses: [bus('C1', 'CRUCE', 2000, -500)],
        ),
        isA<EsperaElBus>().having(
            (f) => f.bus?.metrosHastaLaSubida, 'le falta', closeTo(500, 30)),
      );
      expect(
        guia.leer(
          telefono: m(2000, 300),
          buses: [bus('C1', 'CRUCE', 2000, 290, segundos: 30)],
        ),
        isA<EnElBus>()
            .having((f) => f.metrosParaBajar, 'falta', closeTo(1200, 30)),
      );
      expect(guia.leer(telefono: m(2000, 1200)), isA<BajateEnLaProxima>());
      expect(guia.leer(telefono: m(2030, 1500)), const Llegaste());
    });

    test('en el último bus no hay siguiente que pedir', () {
      guia.tomarElSiguienteBus();
      guia.tomarElSiguienteBus();

      expect(guia.tramo.ruta, 'CRUCE');
    });
  });
}
