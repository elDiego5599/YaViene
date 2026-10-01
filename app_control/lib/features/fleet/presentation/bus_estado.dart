import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../domain/fleet_bus.dart';

/// En qué situación está un bus para el operador.
///
/// Existía repetido en tres sitios —la ficha del mapa, la fila de la lista y
/// la leyenda— y cada copia contaba una historia distinta: la lista conocía
/// tres situaciones, la leyenda tres pero no las mismas, y el marcador del
/// mapa solo dos. Esta es la única.
enum BusEstado {
  /// Reportando posición.
  enLinea,

  /// Lleva más de 90 s sin mandar posición pero la sesión sigue viva: el bus
  /// está ahí y algo pasa con el equipo, no con el turno.
  inactivo,

  /// No está transmitiendo.
  sinSenal,

  /// El operador lo quitó del mapa del pasajero. Es una decisión, no una
  /// avería.
  oculto;

  /// El estado de [bus], con una sola regla de precedencia para todo el panel.
  ///
  /// «Oculto» va primero porque es lo que explica que el pasajero no lo vea, y
  /// es lo único de esta lista que el operador decidió a mano.
  static BusEstado de(FleetBus bus) {
    if (!bus.visible) return oculto;
    if (!bus.online) return bus.isGhost ? inactivo : sinSenal;
    return bus.isGhost ? inactivo : enLinea;
  }

  String get rotulo => switch (this) {
    enLinea => 'En línea',
    inactivo => 'Inactivo',
    sinSenal => 'Sin señal',
    oculto => 'Oculto',
  };

  Color get color => switch (this) {
    enLinea => AppColors.online,
    inactivo => AppColors.ghost,
    sinSenal => AppColors.offline,
    oculto => AppColors.hidden,
  };

  /// La segunda señal, la que no depende de distinguir colores. Los cuatro
  /// dicen lo mismo que el rótulo sin leerlo: emitiendo, en pausa, sin
  /// antena, tapado.
  IconData get icono => switch (this) {
    enLinea => Icons.wifi_tethering,
    inactivo => Icons.pause_circle_outline,
    sinSenal => Icons.wifi_off,
    oculto => Icons.visibility_off,
  };
}
