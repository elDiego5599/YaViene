import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../services/background_keep_alive.dart';
import 'tracking_providers.dart';

/// Cada cuánto la app le dice al servicio de fondo que sigue viva. El
/// servicio se para solo pasados `sinLatidoMaximo` sin señales.
const cadaLatido = Duration(seconds: 20);

/// Enciende el servicio de fondo de Android con el primer aviso armado y lo
/// apaga con el último, lo quite la persona, suene o venza.
///
/// Antes arrancaba al abrir el mapa, con o sin aviso, y solo se paraba en el
/// arranque en frío siguiente: la notificación fija «Seguimiento de buses»
/// se quedaba puesta sin nada que seguir y el socket seguía bajando
/// posiciones con la app en el fondo (auditoría 2026-09, H1).
class SeguimientoSegundoPlano {
  SeguimientoSegundoPlano(this._servicio);

  final ServicioDeFondo _servicio;
  bool _encendido = false;
  Timer? _latidos;

  bool get encendido => _encendido;

  void ajustar({required bool hayAvisos}) {
    if (hayAvisos == _encendido) return;
    _encendido = hayAvisos;
    if (hayAvisos) {
      _servicio.encender();
      _latidos = Timer.periodic(cadaLatido, (_) => _servicio.latido());
    } else {
      _latidos?.cancel();
      _latidos = null;
      _servicio.apagar();
    }
  }

  void dispose() => _latidos?.cancel();
}

/// Vive desde que el mapa lo lee hasta que se cierra la app. Escucha la
/// lista de avisos activos (la misma que tocan la hoja, la pantalla de
/// Notificaciones, el barrido al sonar y el vencimiento) y el ciclo de vida:
/// al cerrar la app se apaga aunque queden avisos —se re-arman al volver a
/// abrirla— y al volver con avisos se enciende otra vez.
final seguimientoSegundoPlanoProvider =
    Provider<SeguimientoSegundoPlano>((ref) {
  final seguimiento =
      SeguimientoSegundoPlano(ref.read(servicioDeFondoProvider));
  ref.listen<Set<String>>(
    activeAlertsProvider,
    (_, avisos) => seguimiento.ajustar(hayAvisos: avisos.isNotEmpty),
    fireImmediately: true,
  );
  final ciclo = AppLifecycleListener(
    onDetach: () => seguimiento.ajustar(hayAvisos: false),
    onResume: () => seguimiento.ajustar(
      hayAvisos: ref.read(activeAlertsProvider).isNotEmpty,
    ),
  );
  ref.onDispose(() {
    ciclo.dispose();
    seguimiento.dispose();
  });
  return seguimiento;
});
