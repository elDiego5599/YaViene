// Un bus del panel puede estar en cuatro situaciones y el operador tiene que
// distinguirlas de un vistazo. Hasta ahora tres de ellas se pintaban con el
// mismo gris y la única diferencia era la palabra, así que el mapa no las
// distinguía en absoluto: un bus inactivo, uno sin señal y uno que el propio
// operador ocultó se dibujaban idénticos (YV-29, T6.4).
//
// Esta prueba vigila las dos cosas que lo arreglan y que es fácil deshacer
// sin querer:
//
// 1. cada estado tiene color propio, y ese color se lee sobre los dos fondos
//    del panel —el blanco de las tarjetas y la arena del escritorio—;
// 2. el color no es la única señal: cada estado trae además su ícono, para
//    quien no distingue verde de ámbar y para la pantalla del pitch, que
//    lava los colores.
//
// El cociente de contraste es el de la WCAG 2.1: (L1 + 0.05) / (L2 + 0.05)
// sobre la luminancia relativa de cada color. `computeLuminance` de Flutter
// es esa misma luminancia, así que no hay una segunda fórmula que mantener.
import 'dart:ui' show Color;

import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_control/core/theme/app_theme.dart';
import 'package:ya_viene_control/features/fleet/domain/fleet_bus.dart';
import 'package:ya_viene_control/features/fleet/presentation/bus_estado.dart';

double _contraste(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final claro = la > lb ? la : lb;
  final oscuro = la > lb ? lb : la;
  return (claro + 0.05) / (oscuro + 0.05);
}

/// Un bus con la combinación que define cada estado.
FleetBus _bus({
  bool visible = true,
  bool online = true,
  bool isGhost = false,
}) => FleetBus(
  busId: 'B-1',
  companyId: 'c-1',
  visible: visible,
  online: online,
  isGhost: isGhost,
);

void main() {
  test('cada estado se lee con un color distinto', () {
    final colores = {for (final e in BusEstado.values) e: e.color};

    expect(
      colores.values.toSet().length,
      BusEstado.values.length,
      reason: 'dos estados comparten color: en el mapa son el mismo bus',
    );
  });

  test('cada color pasa AA (4.5:1) sobre los dos fondos del panel', () {
    // `surface` es la tarjeta de la lista y la caja de la leyenda; `bg` es el
    // escritorio de arena. El texto del estado mide entre 8 y 12 pt, o sea
    // texto chico: la norma pide 4.5:1, no el 3:1 de los títulos.
    for (final estado in BusEstado.values) {
      expect(
        _contraste(estado.color, AppColors.surface),
        greaterThanOrEqualTo(4.5),
        reason: '${estado.rotulo} sobre la tarjeta blanca',
      );
      expect(
        _contraste(estado.color, AppColors.bg),
        greaterThanOrEqualTo(4.5),
        reason: '${estado.rotulo} sobre el fondo de arena',
      );
    }
  });

  test('cada estado trae su propio ícono, no solo su color', () {
    final iconos = {for (final e in BusEstado.values) e: e.icono};

    expect(
      iconos.values.toSet().length,
      BusEstado.values.length,
      reason: 'sin un ícono por estado, el color es la única señal',
    );
  });

  test('un bus se clasifica igual mire quien lo mire', () {
    expect(BusEstado.de(_bus()), BusEstado.enLinea);
    expect(
      BusEstado.de(_bus(isGhost: true, online: false)),
      BusEstado.inactivo,
    );
    expect(BusEstado.de(_bus(online: false)), BusEstado.sinSenal);
    expect(BusEstado.de(_bus(visible: false)), BusEstado.oculto);
    // La sesión sigue viva pero el equipo lleva más de 90 s callado: el
    // operador tiene que verlo, no leer «En línea».
    expect(BusEstado.de(_bus(isGhost: true)), BusEstado.inactivo);
  });

  test('oculto manda sobre el resto: es lo que explica que no se vea', () {
    // Un bus oculto y además sin señal sigue siendo, para el operador, un bus
    // que él apagó. Si se leyera «Sin señal» buscaría una avería que no hay.
    expect(
      BusEstado.de(_bus(visible: false, online: false, isGhost: true)),
      BusEstado.oculto,
    );
  });

  test('el rótulo es el que ya usaban la lista y la leyenda', () {
    expect(BusEstado.enLinea.rotulo, 'En línea');
    expect(BusEstado.inactivo.rotulo, 'Inactivo');
    expect(BusEstado.sinSenal.rotulo, 'Sin señal');
    expect(BusEstado.oculto.rotulo, 'Oculto');
  });
}
