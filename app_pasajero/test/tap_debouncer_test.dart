// El caso que importa en la demo: tocar un bus y enseguida otro. Antes el
// segundo toque recibía el resultado del primero y la selección se perdía.
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_pasajero/features/map/presentation/widgets/tap_debouncer.dart';

void main() {
  group('TapDebouncer', () {
    test('el segundo evento del mismo toque reutiliza el primero', () async {
      final debouncer = TapDebouncer();
      var llamadas = 0;
      final completer = Completer<bool>();
      Future<bool> accion(math.Point<double> _) {
        llamadas++;
        return completer.future;
      }

      final a = debouncer.run(const math.Point<double>(100, 200), accion);
      // map#onMapClick llega con la misma coordenada salvo redondeo.
      final b = debouncer.run(const math.Point<double>(101, 200), accion);

      expect(llamadas, 1);
      expect(identical(a, b), isTrue);
      completer.complete(true);
      expect(await a, isTrue);
      expect(await b, isTrue);
    });

    test('un toque lejano no se come el del otro bus', () async {
      final debouncer = TapDebouncer();
      final puntos = <math.Point<double>>[];
      final completers = <Completer<bool>>[];
      Future<bool> accion(math.Point<double> p) {
        puntos.add(p);
        final c = Completer<bool>();
        completers.add(c);
        return c.future;
      }

      final a = debouncer.run(const math.Point<double>(100, 200), accion);
      final b = debouncer.run(const math.Point<double>(300, 500), accion);

      expect(puntos.length, 2);
      expect(identical(a, b), isFalse);
      completers[0].complete(false);
      completers[1].complete(true);
      expect(await a, isFalse);
      expect(await b, isTrue);
    });

    test('terminado el primero, el mismo punto vuelve a ejecutarse', () async {
      final debouncer = TapDebouncer();
      var llamadas = 0;
      Future<bool> accion(math.Point<double> _) async {
        llamadas++;
        return true;
      }

      const punto = math.Point<double>(100, 200);
      await debouncer.run(punto, accion);
      // Mismo sitio, dentro de los 400 ms, pero la selección ya acabó: es un
      // toque nuevo del usuario (deseleccionar), no el eco del anterior.
      await debouncer.run(punto, accion);

      expect(llamadas, 2);
    });

    test('un fallo en la acción no deja el debouncer trabado', () async {
      final debouncer = TapDebouncer();
      var llamadas = 0;
      Future<bool> accion(math.Point<double> _) async {
        llamadas++;
        if (llamadas == 1) throw StateError('mapa no listo');
        return true;
      }

      const punto = math.Point<double>(10, 10);
      await expectLater(debouncer.run(punto, accion), throwsStateError);
      expect(await debouncer.run(punto, accion), isTrue);
      expect(llamadas, 2);
    });
  });
}
