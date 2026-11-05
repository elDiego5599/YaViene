import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

import '../../../../core/prefs_keys.dart';
import '../../../../core/utils/bus_labels.dart';
import '../../../../core/utils/distancia.dart';
import '../../../../core/widgets/aviso.dart';
import '../../../../core/widgets/cifra_viva.dart';
import '../../../../core/widgets/dialogo.dart';
import '../../../../core/widgets/pildora_navegacion.dart';
import '../../../../core/widgets/placa_bus.dart';
import '../../../../core/widgets/sheet_handle.dart';
import '../../../../core/widgets/tamano_animado.dart';
import '../../../notifications/presentation/providers/distancia_aviso_provider.dart';
import '../../../notifications/presentation/providers/proximity_alerts_provider.dart';
import '../providers/alert_toggle_provider.dart';
import '../providers/distancia_al_bus.dart';
import '../providers/map_view_state.dart';
import '../providers/route_reach_provider.dart';
import '../providers/tracking_providers.dart';
import '../providers/user_location_provider.dart';
import '../utils/geo.dart';
import 'alert_guards.dart' as guards;
import 'map_recenter_button.dart';
import 'ocupacion_bus.dart';
import 'rueda_distancia.dart';
import 'sena_elegir_ruta.dart';
import 'sena_tocar_bus.dart';
import 'sena_tomar_ruta.dart';

class EtaBottomSheet extends ConsumerStatefulWidget {
  const EtaBottomSheet({
    super.key,
    this.alertKey,
    this.ruedaKey,
    this.metricKey,
    this.metricUnitKey,
    this.detailKey,
    this.recenterKey,
    this.onGuideAlertBlocked,
    this.onEligiendoDistancia,
    this.enRespaldo = false,
  });

  /// GlobalKey sobre el botón de aviso: el tour de primer uso lo mide para
  /// abrir su hueco sobre él cuando el usuario toca su primer bus.
  final GlobalKey? alertKey;

  /// La tarjeta del bus entera, que con la rueda abierta es lo que ilumina
  /// el paso del aviso de la guía: la rueda y sus dos botones.
  final GlobalKey? ruedaKey;
  final GlobalKey? metricKey;
  final GlobalKey? metricUnitKey;
  final GlobalKey? detailKey;

  /// Sobre el botón de recentrar: el paso de buses de la guía lo mide para
  /// que su hueco lo abarque entero.
  final GlobalKey? recenterKey;
  final ValueChanged<bool>? onGuideAlertBlocked;

  /// `true` cuando la tarjeta pasa a preguntar la distancia del aviso y
  /// `false` cuando deja de hacerlo. La guía se aparta mientras tanto: su
  /// velo solo deja tocar el botón del aviso, y la rueda quedaría debajo.
  final ValueChanged<bool>? onEligiendoDistancia;

  /// Si la app habla con el respaldo (T2.3): la hoja lo dice en una línea
  /// discreta. Lo pasa el mapa desde `enRespaldoProvider`; la hoja no lee la
  /// configuración del backend por su cuenta, así que montarla en una prueba
  /// no pide backend.
  final bool enRespaldo;

  @override
  ConsumerState<EtaBottomSheet> createState() => _EtaBottomSheetState();
}

class _EtaBottomSheetState extends ConsumerState<EtaBottomSheet>
    with TickerProviderStateMixin {
  /// La superficie de la hoja: se mide para decirle al mapa cuánto tapa.
  final _hojaKey = GlobalKey();

  /// Cuenta un rato quieta tras cada cambio de alto: plegarse, la rueda o
  /// el contenido que crece no reconstruyen la hoja, y medir a medio camino
  /// le diría al mapa un alto que no es. Cada cambio vuelve a empezar la
  /// cuenta; al acabar, se mide. Va con el reloj de los cuadros, no con un
  /// `Timer`: se apaga con la hoja.
  late final AnimationController _quieta =
      AnimationController(vsync: this, duration: AppMotion.rapido)
        ..addStatusListener((estado) {
          if (estado == AnimationStatus.completed) _publishMapInset();
        });

  /// Cuánta hoja hay a la vista: 1 abierta, 0 plegada.
  ///
  /// Es la MISMA variable que mueve el dedo mientras arrastra y la que
  /// remata el camino al soltar. Por eso la hoja va exactamente donde va el
  /// pulgar —no espera a que lo levantes para animarse de golpe— y termina
  /// sola de subir o bajar según hacia dónde ibas.
  late final AnimationController _pliegue;

  /// El contenido se apaga en el último tramo de la bajada: desvaneciéndose
  /// desde el principio, el texto se lee aplastándose contra el borde.
  late final CurvedAnimation _opacidad;

  /// Alto real del contenido, medido al empezar a arrastrar: es lo que
  /// convierte los píxeles del dedo en fracción de hoja.
  final GlobalKey _contenidoKey = GlobalKey();
  double _altoContenido = 0;

  bool _abierta = true;
  double _lastPublishedInset = -1;
  Timer? _refreshTimer;

  /// Histéresis del bloqueo del aviso: una vez bloqueado (bus sin señal o
  /// dentro del radio), permanece bloqueado hasta que el bus se aleje
  /// [margenRearmeMetros] más allá del radio, el mismo margen con el que el
  /// aviso se rearma. Evita que el cruce de umbrales por el movimiento del
  /// bus haga flapear el botón (y la guía) entre bloqueado/desbloqueado.
  bool _blockedLatched = false;
  String? _latchedBusId;

  /// La pregunta de la distancia que espera respuesta, si hay una.
  _Eleccion? _eleccion;

  /// La que se ve en la tarjeta: la de [_eleccion] y, después de
  /// contestarla, la misma mientras se apaga.
  _Eleccion? _eleccionVista;

  /// 0, la tarjeta de siempre; 1, la pregunta de la distancia.
  late final AnimationController _rueda;

  @override
  void initState() {
    super.initState();
    _pliegue = AnimationController(
      vsync: this,
      // Abrir pesa más que cerrar, como algo que se levanta y algo que cae.
      duration: AppMotion.entrada,
      reverseDuration: AppMotion.pausado,
      value: 1,
    );
    _opacidad = CurvedAnimation(
      parent: _pliegue,
      curve: const Interval(0.35, 1, curve: AppMotion.curvaEntrada),
    );
    _rueda = AnimationController(vsync: this, duration: AppMotion.pausado)
      ..addStatusListener((estado) {
        if (estado == AnimationStatus.dismissed &&
            _eleccion == null &&
            mounted) {
          setState(() => _eleccionVista = null);
        }
      });
    // Refresca el texto "Sin señal desde hace X min" de un bus fantasma: sin
    // posiciones nuevas la UI no se reconstruye sola.
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    // Una pregunta sin contestar se cierra sin elegir: quien la espera no
    // arma nada.
    final pendiente = _eleccion;
    _eleccion = null;
    pendiente?.respuesta.complete(null);
    _rueda.dispose();
    _quieta.dispose();
    _opacidad.dispose();
    _pliegue.dispose();
    super.dispose();
  }

  /// Deja la hoja abierta o plegada y termina el camino que quede.
  ///
  /// Con impulso del dedo remata con la física del arrastre (un resorte, el
  /// mismo que usan las hojas del sistema): soltar con brío tiene que
  /// llegar más rápido que soltar quieto.
  void _asentar(bool abrir, {double impulso = 0}) {
    if (AppMotion.reducido(context)) {
      _pliegue.value = abrir ? 1 : 0;
    } else if (impulso != 0) {
      _pliegue.fling(velocity: impulso);
    } else if (abrir) {
      _pliegue.animateTo(1, curve: AppMotion.curvaEntrada);
    } else {
      _pliegue.animateBack(0, curve: AppMotion.curvaSalida);
    }
    if (_abierta == abrir) return;
    HapticFeedback.lightImpact();
    setState(() => _abierta = abrir);
    _publishMapInset();
  }

  void _arrastreEmpieza(DragStartDetails _) {
    final alto = _contenidoKey.currentContext?.size?.height ?? 0;
    // El contenido va recortado por el pliegue: cuando ya está plegada mide
    // 0 y hay que quedarse con la última medida buena.
    if (alto > 0) _altoContenido = alto;
    _pliegue.stop();
  }

  void _arrastreSigue(DragUpdateDetails details) {
    if (_altoContenido <= 0) return;
    final avance = (details.primaryDelta ?? 0) / _altoContenido;
    _pliegue.value = (_pliegue.value - avance).clamp(0.0, 1.0);
  }

  void _arrastreTermina(DragEndDetails details) {
    final porSegundo = details.primaryVelocity ?? 0;
    // Un empujón claro manda sobre dónde quedó la hoja: si el dedo iba
    // hacia abajo, se cierra aunque estuviera casi abierta.
    if (_altoContenido > 0 && porSegundo.abs() > 320) {
      final impulso = -porSegundo / _altoContenido;
      _asentar(porSegundo < 0, impulso: impulso);
      return;
    }
    _asentar(_pliegue.value >= 0.5);
  }

  /// Activa/desactiva la alerta de un bus. La regla de negocio vive en
  /// [alertToggleProvider]; aquí solo se traduce el resultado a háptico,
  /// aviso o ventana.
  Future<void> _toggleAlert(String busId, {String? reemplazarBusId}) async {
    if (reemplazarBusId != null && !await _explicarSeguimiento()) return;
    final result = await ref.read(alertToggleProvider).toggle(busId,
        reemplazarBusId: reemplazarBusId,
        elegirDistancia: (desde, hasta) => _preguntarDistancia(busId,
            inicial: ref.read(distanciaAvisoProvider) ?? distanciaAvisoInicial,
            primeraVez: reemplazarBusId == null,
            avisoActivo: reemplazarBusId != null,
            desde: desde,
            hasta: hasta));
    // Cerró la rueda sin elegir (cancelled): sin háptico ni mensaje, no
    // hay nada que decirle.
    if (!mounted) return;
    if (result.needsHaptic) HapticFeedback.mediumImpact();
    final message = result.message;
    if (message != null) {
      // El límite normal se presenta inline. Aquí solo podría reaparecer por
      // una carrera entre la vista y el controlador: no lo muestres flotando.
      if (message == guards.avisosAlTope) return;
      mostrarAviso(context, message);
      return;
    }
    if (result.outcome == AlertToggleOutcome.deactivated) {
      return;
    }
    if (result.outcome == AlertToggleOutcome.permissionDenied) {
      // Es una pregunta con salida —ir a Ajustes o dejarlo—, así que va en
      // la ventana de la app y no en un aviso que se va solo: en la barra
      // de abajo, «Ajustes» era una palabra verde que desaparecía a los
      // cuatro segundos.
      await mostrarDialogo<void>(
        context,
        (dialogContext) => Dialogo(
          icono: Icons.notifications_off_outlined,
          titulo: 'Activa las notificaciones',
          mensaje: 'Sin ellas, el aviso no puede sonar cuando el bus se '
              'acerque. Actívalas para Ya Viene en los Ajustes.',
          principal: DialogoAccion('Abrir Ajustes', () {
            Navigator.of(dialogContext).pop();
            openAppSettings();
          }),
          secundaria: DialogoAccion(
            'Ahora no',
            () => Navigator.of(dialogContext).pop(),
          ),
        ),
      );
    }
  }

  Future<bool> _explicarSeguimiento() async {
    return _mostrarExplicacion(
      clave: PrefsKeys.explicacionSeguirBusOculta,
      icono: Icons.directions_bus_outlined,
      titulo: 'Ya sigues un bus',
      mensaje: 'Si sigues este bus, el aviso actual se cambiará por el nuevo.',
    );
  }

  Future<bool> _mostrarExplicacion({
    required String clave,
    required IconData icono,
    required String titulo,
    required String mensaje,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(clave) ?? false) {
      return true;
    }
    if (!mounted) return false;
    var noMostrar = false;
    final aceptado = await mostrarDialogo<bool>(
      context,
      (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => Dialogo(
          icono: icono,
          titulo: titulo,
          mensaje: mensaje,
          contenidoAdicional: Material(
            color: Colors.transparent,
            child: Semantics(
              key: const ValueKey('explicacion-no-mostrar'),
              container: true,
              label: 'No volver a mostrar',
              checked: noMostrar,
              onTap: () => setDialogState(() => noMostrar = !noMostrar),
              child: ExcludeSemantics(
                child: InkWell(
                  onTap: () => setDialogState(() => noMostrar = !noMostrar),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48),
                    child: Row(
                      children: [
                        IgnorePointer(
                          child: Checkbox(
                            value: noMostrar,
                            onChanged: (_) {},
                            visualDensity: const VisualDensity(
                              horizontal: -2,
                              vertical: -2,
                            ),
                          ),
                        ),
                        const SizedBox(width: 2),
                        const Expanded(child: Text('No volver a mostrar')),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          principal: DialogoAccion('Entendido', () async {
            if (noMostrar) {
              await prefs.setBool(clave, true);
            }
            if (dialogContext.mounted) Navigator.pop(dialogContext, true);
          }),
          secundaria: DialogoAccion(
            'Cancelar',
            () => Navigator.pop(dialogContext, false),
          ),
        ),
      ),
    );
    return aceptado ?? false;
  }

  /// Ver [distanciaAlBusDesdeTuPunto].
  double? _distanceToBus(BusPosition? bus) =>
      bus == null ? null : distanciaAlBusDesdeTuPunto(ref, bus);

  /// A qué distancia sonaría el aviso de [busId]: la del aviso que ya suena
  /// (puede ser de «Solo esta vez»), si no la guardada y, sin ninguna, el
  /// kilómetro donde arranca la rueda. Es la que dice la fila «Cambiar» y la
  /// que parte el color de la cifra.
  int _radioDe(String busId) =>
      ref.read(proximityAlertsProvider.notifier).radioDe(busId) ??
      ref.watch(distanciaAvisoProvider) ??
      distanciaAvisoInicial;

  /// El bus ya está tan cerca que ni la menor distancia de la rueda deja
  /// [margenAvisoMetros]: ningún aviso sirve. Con una guardada mayor no se
  /// bloquea —con el bus a 800 m y 1 km guardado todavía sirve el de
  /// 500 m, y la rueda solo ofrece lo que deja el margen (dueño,
  /// 2026-10-07)—. Es la misma cuenta que hace [AlertToggleController]
  /// antes de abrir la rueda.
  bool _busAlreadyNear(double? distance) =>
      distance != null && distance <= distanciaAvisoBloqueo;

  /// Histéresis del bloqueo: una vez bloqueado, sigue bloqueado hasta que el
  /// bus se aleje más de [margenRearmeMetros] por fuera del radio (el
  /// movimiento del bus o el GPS cruzando el radio no debe hacer flapear el
  /// botón ni la guía). Se reinicia automáticamente al cambiar de bus.
  bool _applyBlockedHysteresis(
      String busId, bool liveBlocked, double? distance) {
    if (_latchedBusId != busId) {
      _latchedBusId = busId;
      _blockedLatched = liveBlocked;
    } else if (liveBlocked) {
      _blockedLatched = true;
    } else if (distance != null &&
        distance > distanciaAvisoBloqueo + margenRearmeMetros) {
      _blockedLatched = false;
    }
    return _blockedLatched;
  }

  /// Pregunta a qué distancia avisar en la misma tarjeta del bus, sin
  /// ventana encima (dueño, 2026-10-06: «que salga en la misma card en vez
  /// de un popup nuevo»). [primeraVez]: al activar el primer aviso, con
  /// «Guardar» y «Solo esta vez». Si no, es «Cambiar», con «Guardar» y
  /// «Cancelar». `null` si se fue sin elegir: «Cancelar», «atrás» o soltar
  /// el bus. [desde]: la menor que alcanza la ruta. [hasta]: la mayor que
  /// el bus no había pasado al abrirla, para que arranque en una que sirve;
  /// después la rueda sigue al bus.
  Future<({int metros, bool guardar})?> _preguntarDistancia(
    String busId, {
    int inicial = distanciaAvisoInicial,
    bool primeraVez = true,
    bool avisoActivo = false,
    int? desde,
    int? hasta,
  }) {
    // El aviso valida la ruta antes de preguntar: en esa espera la hoja
    // pudo irse.
    if (!mounted) return Future.value();
    _responder(null);
    final eleccion = _Eleccion(
        busId, distanciaEnRueda(inicial, desde: desde, hasta: hasta),
        desde: desde, primeraVez: primeraVez, avisoActivo: avisoActivo);
    setState(() {
      _eleccion = eleccion;
      _eleccionVista = eleccion;
    });
    _rueda
      ..duration = AppMotion.duracion(context, AppMotion.pausado)
      ..forward();
    widget.onEligiendoDistancia?.call(true);
    return eleccion.respuesta.future;
  }

  /// Contesta la pregunta en curso y devuelve la tarjeta a lo de siempre.
  /// [deGolpe] cuando la tarjeta se va de todos modos (otro bus o ninguno):
  /// no hay nada que animar.
  void _responder(({int metros, bool guardar})? respuesta,
      {bool deGolpe = false}) {
    final eleccion = _eleccion;
    if (eleccion == null) return;
    _eleccion = null;
    eleccion.respuesta.complete(respuesta);
    widget.onEligiendoDistancia?.call(false);
    if (deGolpe) {
      _rueda.value = 0;
      setState(() => _eleccionVista = null);
    } else {
      _rueda
        ..duration = AppMotion.duracion(context, AppMotion.pausado)
        ..reverse();
    }
  }

  /// «Cambiar»: la rueda en la distancia de ahora. Lo elegido queda guardado
  /// y, si este bus tiene el aviso puesto, ese aviso pasa a sonar ahí
  /// (dueño, 2026-10-06); el otro aviso puesto sigue a la suya, y así lo dice
  /// la rueda (dueño, 2026-10-07: «es individual»). Solo ofrece lo que el
  /// bus, a [metrosAlBus], todavía no ha pasado —más sonaría ya mismo— y lo
  /// que alcanza la ruta desde el punto del aviso —menos no sonaría nunca
  /// (dueño, 2026-10-07: «hago el cambio a 800 m y se guarda sabiendo que
  /// eso nunca va a sonar»)—. Si eso no deja nada, lo dice sin rueda.
  Future<void> _cambiarDistancia(
      String busId, int actual, double? metrosAlBus) async {
    final desde = distanciaAvisoDesde(_distanciaDeRutaDelAviso(busId));
    final hasta = distanciaAvisoHasta(metrosAlBus);
    if (desde != null && desde > (hasta ?? distanciaAvisoMaxima)) {
      mostrarAviso(
          context, guards.sinDistanciaQueSirva(busId, 'cambiar la distancia'));
      return;
    }
    final elegida = await _preguntarDistancia(
      busId,
      inicial: actual,
      primeraVez: false,
      avisoActivo: ref.read(activeAlertsProvider).contains(busId),
      desde: desde,
      hasta: hasta,
    );
    if (elegida == null || !mounted) return;
    HapticFeedback.selectionClick();
    // Sin aviso armado para este bus no hace nada: no arma ninguno.
    ref
        .read(proximityAlertsProvider.notifier)
        .cambiarRadio(busId, elegida.metros);
    await ref.read(distanciaAvisoProvider.notifier).guardar(elegida.metros);
    // El radio del aviso no es estado de Riverpod: el cuadro se pide aquí.
    if (mounted) setState(() {});
  }

  /// Lo más cerca que pasa la ruta del punto desde el que mide el aviso de
  /// [busId]: su ancla si la tiene; si no, donde está la persona. `null` si
  /// no se sabe: no saber no limita la rueda.
  double? _distanciaDeRutaDelAviso(String busId) {
    final route = ref.read(selectedRouteProvider);
    if (route == null) return null;
    final ubicacion = ref.read(userLocationProvider);
    final punto = ref.read(proximityAlertsProvider.notifier).anchorFor(busId) ??
        (ubicacion.hasPosition ? (ubicacion.lat!, ubicacion.lon!) : null);
    if (punto == null) return null;
    return distanciaDeRuta(
        ref.read(routeTrajectoryProvider(route.id)).value, punto.$1, punto.$2);
  }

  /// Le dice al mapa cuánto tapa la hoja por abajo, para que centre el pin
  /// en lo que queda a la vista: su alto más el hueco sobre el borde (la hoja
  /// va apoyada abajo, `map_screen`). Medido, no supuesto: con números fijos
  /// el botón de tu pin lo dejaba fuera del centro (dueño, 2026-10-16). Sin
  /// ruta también tapa, aunque su texto deje pasar los toques. Se mide al
  /// asentarse, no en cada cuadro: el mapa se desliza con cada cambio.
  void _publishMapInset() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final caja = _hojaKey.currentContext?.findRenderObject() as RenderBox?;
      if (caja == null || !caja.hasSize) return;
      final inset = (caja.size.height +
              PildoraNavegacion.hueco(MediaQuery.viewPaddingOf(context)))
          .roundToDouble();
      if (_lastPublishedInset == inset) return;
      _lastPublishedInset = inset;
      ref.read(mapBottomInsetProvider.notifier).state = inset;
    });
  }

  /// Lo que dice la hoja cuando un aviso armado no pudo sonar porque las
  /// notificaciones de la app están apagadas.
  static const avisoSinPermiso = 'Las notificaciones de Ya Viene están '
      'apagadas: tu aviso sigue activo, pero no puede sonar. Actívalas en '
      'Ajustes.';

  @override
  Widget build(BuildContext context) {
    // Una vez por tanda: el barrido lo reintenta cada cinco segundos y la
    // tarjeta no se repite mientras siga igual.
    ref.listen<bool>(avisosSinPermisoProvider, (antes, ahora) {
      if (ahora && antes != true) {
        mostrarAviso(
          context,
          avisoSinPermiso,
          icono: Icons.notifications_off_outlined,
        );
      }
    });
    final selectedRoute = ref.watch(selectedRouteProvider);
    final selectedBuses = ref.watch(selectedBusesProvider);

    // Cambio de ruta (o borrarla): solo la selección visual pertenece a la
    // ruta anterior. Los AVISOS se conservan: miden en la ruta del bus armado
    // aunque el mapa muestre otra (diseño por ruta); cancelarlos aquí sin
    // disarmAlert los mataba en silencio y dejaba suscripciones abiertas.
    ref.listen<RouteInfo?>(selectedRouteProvider, (previous, next) {
      if (previous?.id == next?.id) return;
      ref.read(selectedBusesProvider.notifier).clear();
    });

    // Al quitar la ubicación (pin manual o GPS) la selección de bus no tiene
    // sentido (sin ubicación no se pueden tocar buses). Los avisos se
    // conservan: sin posición no miden (se pausan) y reanudan al volver la
    // ubicación, en vez de cancelarse silenciosamente.
    ref.listen<UserLocationState>(userLocationProvider, (previous, next) {
      final hardLoss = next.mode == UserLocationMode.denied ||
          next.mode == UserLocationMode.permanentDenied ||
          next.mode == UserLocationMode.gpsFailed ||
          next.mode == UserLocationMode.sinPunto;
      if (previous?.hasPosition == true && !next.hasPosition && hardLoss) {
        ref.read(selectedBusesProvider.notifier).clear();
      }
    });

    // Tocar un bus abre la hoja: su tarjeta ya no se pliega, así que si el
    // usuario venía con la hoja plegada hay que devolverla a su sitio.
    ref.listen<Set<String>>(selectedBusesProvider, (previous, next) {
      if (previous != null && previous.isEmpty && next.isNotEmpty) {
        _asentar(true);
      }
      // Soltar el bus (o cambiarlo por otro) deja la pregunta sin contestar.
      final eleccion = _eleccion;
      if (eleccion != null && (next.isEmpty || next.first != eleccion.busId)) {
        _responder(null, deGolpe: true);
      }
    });

    if (selectedRoute == null) {
      _publishMapInset();
      // Sin ruta tampoco se muestra la hoja: si aún no hay ubicación invita
      // a tocar el mapa desde el primer momento. Y se pliega como las demás:
      // es texto, y el mapa de debajo es lo que el usuario quiere tocar.
      return _sheetShell(
        toggleable: true,
        child: _buildEmptyState(const []),
      );
    }

    _publishMapInset();

    // La hoja habla de los buses que el usuario está viendo: los mismos que
    // pinta el mapa, que ahora son todos los de la ruta.
    final busesAsync = ref.watch(busPositionsSourceProvider(selectedRoute.id));
    final buses = busesAsync.value ?? const <BusPosition>[];
    final busById = {for (final b in buses) b.busId: b};

    // Bus seleccionado que ya no está en la ruta (left/hidden/removed):
    // se quita de la selección visual. Los AVISOS activos NO se tocan: un
    // batch transitorio sin el bus (reconexión, silencio momentáneo) no debe
    // destruir la alerta del usuario; solo el disparo, el usuario o el cierre
    // de sesión la quitan.
    // Un batch VACÍO tampoco limpia la selección: el primer batch tras una
    // reconexión del socket suele llegar vacío y eso no significa que el bus
    // desapareció de la ruta.
    ref.listen<AsyncValue<List<BusPosition>>>(
        busPositionsSourceProvider(selectedRoute.id), (prev, next) {
      final loaded = next.value;
      if (loaded == null || loaded.isEmpty) return;
      final ids = {for (final b in loaded) b.busId};
      final selNotifier = ref.read(selectedBusesProvider.notifier);
      for (final id in ref.read(selectedBusesProvider).toList()) {
        if (ids.contains(id)) continue;
        if (ref.read(selectedBusesProvider).contains(id)) {
          selNotifier.toggleBus(id);
        }
      }
    });

    // La tarjeta del bus seleccionado es la única que no se pliega: es la que
    // trae el aviso, y plegarla justo después de tocar el bus escondía el
    // botón que el usuario venía a buscar. Se cierra soltando el bus, no
    // arrastrando la hoja. Las demás tarjetas solo explican o invitan, así
    // que se pliegan para devolver el mapa entero.
    final tarjetaDeBus = selectedBuses.isNotEmpty;
    // El bus sin señal tiene otra tarjeta; la pregunta va en la de siempre,
    // y la hoja funde la una en la otra como al cambiar de bus.
    final preguntaSinSenal = tarjetaDeBus &&
        _eleccion != null &&
        _staleLabel(busById[selectedBuses.first]) != null;

    return _sheetShell(
      toggleable: !tarjetaDeBus,
      child: tarjetaDeBus
          ? KeyedSubtree(
              key: ValueKey('sheet-bus-${selectedBuses.first}'
                  '${preguntaSinSenal ? '-rueda' : ''}'),
              child: _buildSingleBusState(
                selectedBuses.first,
                busById[selectedBuses.first],
                buses,
              ),
            )
          : _buildEmptyState(buses),
    );
  }

  /// Carcasa de la hoja: asa de arrastre + contenedor redondeado.
  ///
  /// [toggleable] controla el plegado por arrastre o toque del asa. La única
  /// tarjeta que no se pliega es la del bus seleccionado.
  Widget _sheetShell({required Widget child, required bool toggleable}) {
    // Mientras el selector de ruta está arriba, la hoja se aparta.
    //
    // Las dos se apoyan en el mismo borde inferior: con el selector encima,
    // esta asomaba por debajo como un segundo borde redondeado, y bajar el
    // selector descubría otra tarjeta en vez del mapa. Se hunde un palmo y
    // se apaga —no cruza la pantalla peleando con el selector, que entra por
    // el mismo lado— y vuelve sola cuando el selector se cierra, también
    // cuando no se eligió ruta, que es cuando hace falta que vuelva.
    final apartada = ref.watch(routeSelectorOpenProvider);
    final paso = AppMotion.duracion(context, AppMotion.pausado);
    return IgnorePointer(
      ignoring: apartada,
      child: AnimatedSlide(
        offset: apartada ? const Offset(0, 0.4) : Offset.zero,
        duration: paso,
        curve: apartada ? AppMotion.curvaSalida : AppMotion.curvaEntrada,
        child: AnimatedOpacity(
          opacity: apartada ? 0 : 1,
          duration: paso,
          curve: apartada ? AppMotion.curvaSalida : AppMotion.curvaEntrada,
          // A lo ancho de la barra de abajo y apoyada donde ella: la hoja
          // crece de la barra (dueño, 2026-10-16), no es otra tarjeta de
          // borde a borde con la barra flotando encima.
          child: Padding(
            padding: EdgeInsets.only(
              left: PildoraNavegacion.lado,
              right: PildoraNavegacion.lado,
              bottom:
                  PildoraNavegacion.hueco(MediaQuery.viewPaddingOf(context)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // El botón de recentrar viaja pegado al borde de arriba de la
                // hoja: sube y baja con ella al plegarse, y se va con ella
                // cuando el selector ocupa la pantalla. Suelto sobre el mapa
                // habría que estarle calculando el hueco, y con la hoja sin
                // ruta —que no empuja el mapa pero sí tapa el tercio de
                // abajo— se quedaba debajo.
                // Su canto derecho, a plomo con el de la hoja.
                //
                // Con la rueda de la distancia abierta se aparta, como la
                // barra: la pregunta se contesta antes de mover el mapa, y
                // en el teléfono más bajo (320×568) la rueda no cabe con él
                // encima ahora que la tarjeta se apoya sobre el hueco de la
                // barra (le faltaban 6 px). Suelta su sitio más rápido de lo
                // que la rueda crece (200 contra 360, con la misma curva) y
                // vuelve cuando la rueda ya se apagó: en ningún cuadro se
                // suman los dos.
                TamanoAnimado(
                  duracion: AppMotion.rapido,
                  alineacion: Alignment.bottomRight,
                  child: _eleccionVista == null
                      ? Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: MapRecenterButton(key: widget.recenterKey),
                        )
                      : const SizedBox.shrink(),
                ),
                Flexible(
                  child: _sheetBody(child: child, toggleable: toggleable),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sheetBody({required Widget child, required bool toggleable}) {
    // Techo al texto del sistema, y solo aquí dentro.
    //
    // La hoja es la pantalla del número grande: 64 px de base. Al triple
    // —lo que ofrece iOS en tamaños de accesibilidad— mide 192 y la hoja
    // entera pasa de los 844 de la pantalla, así que se salía 448 px por
    // abajo. No cabe hacerla desplazable: la hoja se arrastra con el dedo
    // para plegarla, y un desplazamiento dentro le robaría ese gesto.
    //
    // El doble sí cabe entero, y el doble es exactamente lo que pide la
    // norma de accesibilidad (WCAG 1.4.4): el texto tiene que poder
    // duplicarse sin perder contenido ni funciones. De ahí para arriba la
    // hoja se queda en su tamaño máximo en vez de recortar lo que muestra.
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 2.0,
      child: _cuerpoDeLaHoja(child: child, toggleable: toggleable),
    );
  }

  Widget _cuerpoDeLaHoja({required Widget child, required bool toggleable}) {
    return NotificationListener<SizeChangedLayoutNotification>(
      onNotification: (_) {
        _quieta.forward(from: 0);
        return true;
      },
      child: SizeChangedLayoutNotifier(
          child: _superficie(child: child, toggleable: toggleable)),
    );
  }

  Widget _superficie({required Widget child, required bool toggleable}) {
    return GestureDetector(
      key: _hojaKey,
      // El dedo manda: la hoja baja y sube pegada al pulgar, y al soltar
      // termina sola el camino que falte.
      onVerticalDragStart: toggleable ? _arrastreEmpieza : null,
      onVerticalDragUpdate: toggleable ? _arrastreSigue : null,
      onVerticalDragEnd: toggleable ? _arrastreTermina : null,
      child: DecoratedBox(
        key: widget.detailKey,
        // La forma de la barra estirada hacia arriba: cantos de 32, la
        // mitad de sus 64 de alto, así que abajo los dos contornos son uno.
        // El filo de un pixel la separa del mapa mejor que una sombra
        // ancha (sobre un mapa lleno de color la sombra se lee como
        // suciedad), y la sombra es la de la barra, que ahora es esta.
        decoration: ShapeDecoration(
          // Blanca como la barra de la que crece (dueño, 2026-10-16): lo
          // blanco que lleva encima se despega con sombra.
          color: AppColors.surface,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(AppRadius.sheet)),
            side: BorderSide(color: AppColors.hairline),
          ),
          shadows: [
            BoxShadow(
              color: AppColors.primaryDeep.withValues(alpha: 0.08),
              blurRadius: 24,
              offset: const Offset(0, 8),
            )
          ],
        ),
        child: SizedBox(
            width: double.infinity,
            child: _conSitioParaLaBarra(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Semantics(
                    button: toggleable,
                    // El asa es dos rayas de 4 px: leída sola no dice nada, y
                    // es el único control que pliega la tarjeta sin arrastrar.
                    label: !toggleable
                        ? null
                        : _abierta
                            ? 'Plegar la tarjeta'
                            : 'Abrir la tarjeta',
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: toggleable ? () => _asentar(!_abierta) : null,
                      child: AnimatedBuilder(
                        animation: _pliegue,
                        builder: (context, _) {
                          final abierta = _pliegue.value;
                          return Padding(
                            // Plegada, el asa es lo único que queda: se le deja
                            // el mismo aire arriba y abajo para que no parezca
                            // un resto de la tarjeta, sino un control.
                            padding: EdgeInsets.only(
                                top: 14, bottom: 14 + 4 * abierta),
                            child: SheetHandle(
                              key: const ValueKey('sheet-handle'),
                              abierta: abierta,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  // En el respaldo, una línea lo dice (T2.3). Va fuera del
                  // pliegue: plegada la hoja, los buses del mapa siguen siendo
                  // los del respaldo, así que la línea no se esconde con el
                  // resto. Y aparte del contenido, para no tocar lo que dice
                  // cada estado, el «Toca un bus en el mapa» incluido.
                  if (widget.enRespaldo)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: Text(
                        'Conectado al respaldo',
                        key: const ValueKey('sheet-respaldo'),
                        style: AppTextStyles.pie,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  // El pliegue: el alto se recorta anclado bajo el asa —dentro
                  // del contenedor, no fuera— para que nunca coma las esquinas
                  // redondeadas mientras la hoja crece o baja. El factor es el
                  // controlador crudo, sin curva: si le pusiéramos una, el
                  // arrastre dejaría de ir donde va el dedo.
                  SizeTransition(
                    key: const ValueKey('sheet-pliegue'),
                    sizeFactor: _pliegue,
                    alignment: Alignment.topCenter,
                    child: FadeTransition(
                      opacity: _opacidad,
                      child: KeyedSubtree(
                        key: _contenidoKey,
                        // El alto de la hoja sigue al del contenido. Sin esto,
                        // al tocar un bus la hoja saltaba de un cuadro al
                        // siguiente al alto de la tarjeta —y al soltarlo, al
                        // del estado vacío—, y el fundido de dentro no lo
                        // disimulaba: lo que el ojo sigue es el borde de
                        // arriba.
                        child: TamanoAnimado(
                          duracion: AppMotion.pausado,
                          alineacion: Alignment.topCenter,
                          child: AnimatedSwitcher(
                            duration:
                                AppMotion.duracion(context, AppMotion.pausado),
                            // Fundido encadenado: lo viejo se apaga en el
                            // primer 40 % y lo nuevo entra a partir del 30 %.
                            // Cruzados a la vez, el número del bus y el texto
                            // del estado vacío se leían uno encima del otro a
                            // medio cambio.
                            switchInCurve: const Interval(0.3, 1,
                                curve: AppMotion.curvaEntrada),
                            switchOutCurve: const Interval(0.6, 1,
                                curve: AppMotion.curvaSalida),
                            // El contenido entrante y el saliente se apilan por
                            // su borde superior, que es el que no se mueve:
                            // apilados por el centro (lo que hace por defecto)
                            // el texto saltaba hacia arriba mientras la hoja
                            // todavía bajaba.
                            //
                            // Lo que sale va posicionado para que no cuente en
                            // el alto: así el tamaño viaja directo al del
                            // contenido nuevo en vez de esperar a que el viejo
                            // termine de irse. Y sin recorte, porque el viejo
                            // puede ser más alto que el alto que ya está
                            // menguando.
                            layoutBuilder: (actual, anteriores) => SizedBox(
                              width: double.infinity,
                              child: Stack(
                                alignment: Alignment.topCenter,
                                clipBehavior: Clip.none,
                                children: [
                                  for (final anterior in anteriores)
                                    Positioned(
                                      top: 0,
                                      left: 0,
                                      right: 0,
                                      child: anterior,
                                    ),
                                  if (actual != null) actual,
                                ],
                              ),
                            ),
                            transitionBuilder: (child, animation) =>
                                FadeTransition(
                              opacity: animation,
                              child: SlideTransition(
                                position: Tween<Offset>(
                                  // Un dedo de recorrido, no más: acompaña al
                                  // pliegue en vez de competir con él.
                                  begin: Offset(0,
                                      0.06 * AppMotion.desplazamiento(context)),
                                  end: Offset.zero,
                                ).animate(animation),
                                child: child,
                              ),
                            ),
                            child: child,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            )),
      ),
    );
  }

  /// Abajo, la barra de pestañas va dentro de la hoja: se le guarda su
  /// alto, con un filo que separa lo de la hoja de las pestañas. Crece y
  /// mengua con la barra; fuera de las pestañas, o con la barra apartada
  /// (la guía, el teclado), no queda nada.
  ///
  /// Si lo de la hoja no cabe —la tarjeta del bus con el aviso puesto en el
  /// teléfono más bajo, o con el texto al doble—, se desplaza por dentro en
  /// vez de salirse por arriba; el sitio de la barra queda fuera, quieto.
  /// Cuando cabe no hay nada que desplazar y el arrastre del asa sigue
  /// siendo de la hoja.
  Widget _conSitioParaLaBarra({required Widget child}) {
    final barra = PildoraVisible.of(context);
    final contenido = SingleChildScrollView(primary: false, child: child);
    if (barra == 0) return contenido;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(child: contenido),
        Opacity(
          opacity: barra,
          child: Container(
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            color: AppColors.hairline,
          ),
        ),
        SizedBox(height: (PildoraNavegacion.alto - 1) * barra),
      ],
    );
  }

  Widget _buildEmptyState(List<BusPosition> buses) {
    final hasPosition =
        ref.watch(userLocationProvider.select((s) => s.hasPosition));
    final route = ref.watch(selectedRouteProvider);

    // La distancia real, no el umbral: el usuario necesita saber cuánto le
    // falta para decidir si mueve el pin o cambia de ruta.
    final routeDistance =
        route == null ? null : ref.watch(routeDistanceToUserProvider(route.id));
    final routeTooFar =
        routeDistance != null && routeDistance > distanciaAvisoMaxima;

    final String stateKey;
    final String title;
    final String subtitle;
    final IconData icon;
    Widget? dibujo;
    if (!hasPosition) {
      stateKey = 'empty-no-position';
      // El pin marca dónde se toma la ruta, no dónde está la persona
      // (dueño, 2026-11-05): al soltarlo salta a la ruta y se mide solo la
      // ruta hasta ahí. Lo de arrastrar el pin no se dice aquí: esta frase
      // solo se ve mientras NO hay pin. Vive en la píldora, junto al pin.
      title = 'Toca el mapa donde tomas tu bus';
      subtitle = 'Tu punto se pega a la ruta y medimos hasta ahí';
      icon = Icons.pin_drop_outlined;
      // El pin del mapa saltando a su ruta, en vez de la mano (dueño,
      // 2026-11-05, «ponle un icono más bonito»).
      dibujo = const SenaTomarRuta(key: ValueKey('sena-tomar-ruta'));
    } else if (route == null) {
      stateKey = 'empty-no-route';
      title = 'Escoge empresa y ruta';
      // «Aquí» y no «la barra de arriba»: el bloque entero abre el
      // selector, porque ahí es donde la gente tocaba (dueño, 2026-09-28).
      subtitle = 'Toca aquí para elegir la empresa y su ruta';
      icon = Icons.route_outlined;
      // Fichas de ruta en abanico y la del frente escogida (dueño,
      // 2026-11-05: el ícono gris se veía horrible junto al pin).
      dibujo = const SenaElegirRuta(key: ValueKey('sena-elegir-ruta'));
    } else if (buses.isEmpty && routeTooFar) {
      // El caso más confuso de todos: el mapa está vacío no porque no haya
      // buses, sino porque la ruta entera pasa lejos. Decirlo evita que el
      // usuario espere sentado un bus que no viene por aquí.
      stateKey = 'empty-route-far';
      title = 'Esta ruta no pasa cerca de ti';
      subtitle = 'Lo más que se acerca su recorrido son '
          '${kmLabel(routeDistance)} de tu punto. '
          'Mueve tu punto de espera o elige otra ruta';
      icon = Icons.wrong_location_outlined;
    } else if (buses.isEmpty) {
      stateKey = 'empty-no-buses';
      title = 'No hay buses en el mapa';
      subtitle =
          'Cuando un bus de esta ruta transmita posición, aparecerá aquí';
      icon = Icons.directions_bus_outlined;
    } else {
      stateKey = 'empty-pick-bus';
      title = 'Toca un bus en el mapa';
      subtitle = 'Selecciona un bus para darle seguimiento';
      icon = Icons.touch_app_outlined;
      // El bus del mapa con su toque, en vez de la mano (dueño,
      // 2026-09-27). Es el estado que más se ve: el que queda con la ruta
      // puesta y los buses en el mapa.
      dibujo = const SenaTocarBus(key: ValueKey('sena-tocar-bus'));
    }

    // Sin ruta, el bloque entero abre el selector: la gente tocaba el
    // ícono esperando que pasara algo (dueño, 2026-09-28).
    final abreSelector = stateKey == 'empty-no-route';

    final contenido = Column(
      children: [
        // El icono va en su medallón, como los de los tiles del selector y
        // el de la píldora de ubicación: suelto sobre la hoja era un glifo
        // gris flotando en el hueco más grande de la pantalla. No dice nada
        // que no diga el título, así que en voz alta no existe.
        //
        // También cuando abre el selector va en su gris: el verde se probó y
        // no gustó (dueño, 2026-09-29). Lo tocable lo dicen «Toca aquí» y
        // el hundido al tocar.
        ExcludeSemantics(
          child: Container(
            key: abreSelector ? const ValueKey('escoge-ruta-icono') : null,
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.hairline),
              boxShadow: AppShadows.soft,
            ),
            child:
                dibujo ?? Icon(icon, color: AppColors.textSecondary, size: 26),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          title,
          style: AppTextStyles.subtitulo,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          subtitle,
          style: AppTextStyles.cuerpo.copyWith(color: AppColors.textSecondary),
          textAlign: TextAlign.center,
        ),
      ],
    );

    return KeyedSubtree(
      key: ValueKey(stateKey),
      child: Padding(
        padding:
            const EdgeInsets.fromLTRB(AppSpacing.lg, 10, AppSpacing.lg, 40),
        // Título y frase son una sola cosa: "No hay buses en el mapa" y
        // el porqué. Sueltos, hay que deslizar dos veces para enterarse
        // de por qué la hoja está vacía.
        child: abreSelector
            ? _EstadoTocable(
                key: const ValueKey('empty-no-route-boton'),
                onTap: () {
                  HapticFeedback.lightImpact();
                  ref.read(pedirSelectorProvider.notifier).state++;
                },
                child: contenido,
              )
            : MergeSemantics(child: contenido),
      ),
    );
  }

  Widget _buildSingleBusState(
      String busId, BusPosition? bus, List<BusPosition> buses) {
    final activeAlerts = ref.watch(activeAlertsProvider);
    final isActive = activeAlerts.contains(busId);
    String? activeOtherBusId;
    for (final activeBusId in activeAlerts) {
      if (activeBusId != busId) {
        activeOtherBusId = activeBusId;
        break;
      }
    }
    final locationState = ref.watch(userLocationProvider);
    final staleLabel = _staleLabel(bus);
    final ghostBlocked = !isActive && bus != null && bus.isGhostBus;
    final distance = _distanceToBus(bus);
    // Ya escuchado por `_distanceToBus`: aquí solo se lee.
    final ocupacion = bus == null
        ? null
        : ocupacionEnRuta(ref.read(seguidorRutaProvider(bus.routeId)), bus);
    final route = ref.watch(selectedRouteProvider);
    // F6: misma "ruta - placa" que ya usa Notificaciones, en vez de "Bus $id"
    // crudo — el mismo bus no debe tener dos nombres distintos en la app.
    final busLabel = routePlateLabel(
      busId: busId,
      routeName: route?.name,
      routeId: route?.id,
    );
    // Encima de la distancia va solo "Bus" y la placa: la ruta ya la nombra
    // la píldora de arriba, y lo que el pasajero coteja con el bus que se
    // acerca es la placa. Leído dice lo mismo, así que no lleva etiqueta
    // aparte para la voz.
    final busTitulo = 'Bus ${busPlaca(busId)}';

    // El aviso mide desde el pin con el que se armó, y la hoja también
    // (`_distanceToBus`). Si después el pasajero pone el pin en otro sitio y
    // vuelve a este bus, el número es el del pin anterior: decir "de ti"
    // ahí confundía, porque parece la distancia al pin nuevo. Menos de un
    // metro de diferencia es el mismo pin.
    final ancla = ref.read(proximityAlertsProvider.notifier).anchorFor(busId);
    final desdePinAnterior = isActive &&
        ancla != null &&
        (!locationState.hasPosition ||
            haversineMeters(ancla.$1, ancla.$2, locationState.lat!,
                    locationState.lon!) >=
                1);
    final referencia = desdePinAnterior ? 'de tu pin anterior' : 'de ti';

    // Defensa: el bus seleccionado ya no está en la ruta (aún no se procesó
    // la limpieza) → volvemos al estado "toca un bus", no a un bus fantasma.
    if (bus == null) return _buildEmptyState(buses);

    // El bus ya está dentro de la distancia del aviso: no se puede activar.
    final alreadyNear = !isActive && _busAlreadyNear(distance);
    final liveBlocked =
        ghostBlocked || alreadyNear || !locationState.hasPosition;
    // La ruta no pasa cerca: el aviso no sonaría nunca. Va FUERA de la
    // histéresis a propósito. La histéresis existe para que el bus moviéndose
    // alrededor de la distancia del aviso no haga parpadear el botón; esto no
    // se mueve —depende del recorrido y del pin, no del bus— y meterlo
    // dentro dejaría el botón trabado en bloqueado después de mover el pin
    // hasta la ruta.
    final routeTooFar = !isActive &&
        (route == null
            ? false
            : ref.watch(routeTooFarFromUserProvider(route.id)));
    final blocked =
        _applyBlockedHysteresis(busId, liveBlocked, distance) || routeTooFar;
    final alertButtonLabel = isActive
        ? 'Aviso activado'
        : activeOtherBusId != null
            ? 'Avisarme cuando esté cerca'
            : ghostBlocked
                ? 'Bus sin señal'
                : routeTooFar
                    ? 'Esta ruta no pasa cerca'
                    : blocked
                        ? 'El bus ya está cerca'
                        : 'Avisarme cuando esté cerca';

    // La distancia del aviso, bajo el botón, con su «Cambiar». Solo con el
    // aviso activo: sin él la pregunta la rueda al activarlo, y una fila que
    // ofrece cambiar algo que todavía no va a sonar confunde (dueño,
    // 2026-10-06).
    //
    // En iPhone, con el aviso activo, sube a la nota de encima del botón:
    // ese sitio era de «Deja Ya Viene abierta y la pantalla encendida», que
    // sobra porque iPhone sale cuando haya avisos por push (dueño,
    // 2026-10-06). En Android la nota de cómo cuidar el aviso se queda.
    final radio = _radioDe(busId);
    void cambiar() => _cambiarDistancia(busId, radio, distance);
    final distanciaEnNota =
        isActive && Theme.of(context).platform == TargetPlatform.iOS;
    final filaDistancia = isActive && !distanciaEnNota
        ? _CambiarDistancia(metros: radio, onTap: cambiar)
        : null;
    // Con la fila debajo, el aire de abajo lo pone su propio alto de 48: los
    // 20 de siempre la alejaban del botón al que pertenece.
    final aireAbajo = filaDistancia == null ? 20.0 : 6.0;

    final eleccion = _eleccionVista;
    // Sin señal: excepción importante, se marca con coral. Salvo mientras
    // pregunta la distancia, que va en la tarjeta de siempre.
    if (staleLabel != null && _eleccion == null) {
      return Column(
        children: [
          const SizedBox(height: 10),
          const Icon(Icons.wifi_off_outlined, color: AppColors.coral, size: 56),
          const SizedBox(height: 10),
          Text(staleLabel,
              style:
                  AppTextStyles.subtitulo.copyWith(color: AppColors.textBody)),
          const SizedBox(height: AppSpacing.xs),
          Text("$busLabel: conserva su última posición",
              style: AppTextStyles.etiqueta
                  .copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: AppSpacing.lg),
          Padding(
            padding:
                EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, aireAbajo),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _StickyAlertButton(
                  key: widget.alertKey,
                  onBlockedChanged: widget.onGuideAlertBlocked,
                  isActive: isActive,
                  blocked: isActive ? false : blocked,
                  // Esta rama es la del bus sin señal (`_staleLabel` solo
                  // existe para un bus fantasma), así que sin aviso puesto el
                  // botón siempre está bloqueado por la señal: no hay tercer
                  // rótulo.
                  label: alertButtonLabel,
                  onPressed: () => _toggleAlert(
                    busId,
                    reemplazarBusId: activeOtherBusId,
                  ),
                ),
                if (filaDistancia != null) filaDistancia,
              ],
            ),
          ),
        ],
      );
    }

    // Con el aviso activo, en Android el detalle explica que se puede
    // cambiar de app, pero no deslizar Ya Viene fuera de recientes ni forzar
    // su cierre. En iPhone dice a qué distancia suena, con su «Cambiar».
    //
    // El detalle va en una nota con su ícono (diseño «A», dueño 2026-09-30)
    // y no en un párrafo gris suelto bajo el número: el ícono dice de un
    // vistazo de qué va —coral si algo impide el aviso, verde si el aviso
    // está puesto, tinta si solo falta un paso— y el texto se queda corto.
    // La ruta lejos decía antes «…el aviso no sonaría. Mueve tu punto o
    // elige otra ruta»; el botón ya dice «Esta ruta no pasa cerca», así que
    // la nota solo cuenta qué hacer.
    final _Nota? stateDetail = isActive
        ? distanciaEnNota
            ? _Nota.distancia(radio, cambiar)
            : null
        : !locationState.hasPosition
            ? const _Nota.paso(
                Icons.pin_drop_outlined, "Toca el mapa donde tomas tu bus")
            : routeTooFar
                ? const _Nota.impide(
                    Icons.wrong_location_outlined,
                    "La ruta no pasa cerca de tu punto. Muévelo o elige "
                    "otra ruta.")
                : distance == null
                    ? const _Nota.paso(Icons.location_searching_rounded,
                        "Buscando la posición del bus…")
                    : null;

    // Estado → color de la métrica grande (número o palabra).
    Color colorCifra;
    String metricText = '';
    String? metricUnit;
    // Lo que se lee en voz alta. Cuando la métrica es una palabra
    // —"Calculando"— la palabra ya es la frase entera.
    String metricSpoken = '';
    if (!locationState.hasPosition && !desdePinAnterior) {
      // Gris de texto, no gris de deshabilitado: aquí no hay número sino
      // una palabra de 28 en peso 800, y `textDisabled` daba 2,4:1 sobre
      // la arena. Este da 4,4:1 y sigue siendo el gris apagado que le
      // toca a un estado sin dato.
      colorCifra = AppColors.textSecondary;
      metricText = "Sin tu ubicación";
      metricSpoken = metricText;
    } else if (distance == null) {
      colorCifra = AppColors.textSecondary;
      metricText = "Calculando";
      metricSpoken = metricText;
    } else {
      // V1: el número hero carga la urgencia en su propio color, en vez de
      // quedarse siempre en el mismo azul — lejos, acercándose o ya casi.
      colorCifra = colorDeDistancia(distance, radio);
      final parts = distanciaPartes(distance, referencia);
      metricText = parts.$1;
      metricUnit = parts.$2;
      metricSpoken = distanciaHablada(distance, referencia);
    }
    final isNumberMetric = metricUnit != null;

    // Métrica principal: número grande que respira, o el estado en
    // palabras. F10: override sobre AppTextStyles.etaNumber (mismo
    // TextStyle base) en vez de un literal duplicado.
    // El número y su unidad son dos bloques —64 y 15— y en voz alta
    // se leerían como "850" y luego "m de ti", con una pausa en
    // medio y la unidad abreviada. Aquí se dicen en una sola frase.
    final cifra = Semantics(
      label: metricSpoken,
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // El color del número pasa de un tramo al otro en vez de
          // saltar cuando el bus se acerca.
          TweenAnimationBuilder<Color?>(
            tween: ColorTween(end: colorCifra),
            duration: AppMotion.duracion(context, AppMotion.pausado),
            curve: AppMotion.curvaCambio,
            // El número es `dato`, el rol que existe para él.
            // Cuando en su sitio va una palabra —"Sin señal",
            // "Llegando"— no cabe a 64 ni tendría sentido en w200:
            // pasa a `display`, que es el otro rol grande, y ocupa
            // el mismo hueco. El número gira cifra a cifra con cada
            // posición nueva (`CifraViva`); la palabra no tiene
            // cifras y va quieta.
            builder: (context, color, _) => isNumberMetric
                ? CifraViva(
                    metricText,
                    key: widget.metricKey,
                    valor: distance,
                    style: AppTextStyles.dato.copyWith(color: color),
                  )
                : Text(
                    metricText,
                    key: widget.metricKey,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.display.copyWith(color: color),
                  ),
          ),
          if (metricUnit != null) ...[
            const SizedBox(height: 6),
            Text(
              metricUnit,
              key: widget.metricUnitKey,
              style: AppTextStyles.cuerpoFuerte
                  .copyWith(color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );

    final tarjeta = Padding(
      // La tarjeta del bus se muestra entera, siempre: es la única que no se
      // pliega, así que no tiene una versión corta que ajustar.
      padding: EdgeInsets.fromLTRB(AppSpacing.lg, 6, AppSpacing.lg, aireAbajo),
      child: Column(
        key: widget.ruedaKey,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Sin franja de color arriba (diseño «A», dueño 2026-09-30): el
          // número ya lleva la urgencia en su color y la franja la repetía.
          // Los 18 que la separaban del título pasan a 12, y a 8 desde que
          // la tarjeta lleva la ocupación (dueño, 2026-10-27: el mapa
          // quedaba sin espacio): el asa de la hoja queda justo encima.
          const SizedBox(height: 8),
          // Quién es y cuánto falta, en una tarjeta con marco (prueba del
          // dueño, 2026-09-30): blanca con el filo y la sombra suave de las
          // filas del selector, que es lo que la separa de la hoja blanca
          // (dueño, 2026-10-16). [AppRadius.card] y no
          // `lg`: mide casi 200 de alto, y 16 en una caja así se ve recto.
          // La nota y el botón van fuera: son lo que la app dice y lo que
          // se hace, no lo que se mira.
          Container(
            key: const ValueKey('hoja-tarjeta'),
            width: double.infinity,
            // 12 arriba y 14 abajo (antes 14 y 18; dueño, 2026-10-27, más
            // mapa): la pista de la ocupación cierra la tarjeta y no la
            // unidad, que no traía aire propio debajo.
            padding: const EdgeInsets.only(top: 12, bottom: 14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: AppColors.hairline),
              boxShadow: AppShadows.soft,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Identidad del bus: «BUS» en versalitas y la placa como placa
                // (ver `_Placa`). Lo que el pasajero coteja con el bus que
                // llega es la placa, y así se reconoce antes de leerla. Leído
                // es una sola frase, «Bus SQA223», igual que antes.
                Semantics(
                  label: busTitulo,
                  excludeSemantics: true,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // `pie` en versalitas abiertas: rotula, no compite con la
                      // placa. El 1,4 de espaciado es el de las versalitas del
                      // menú («RUTA ACTIVA», 1,2) un punto más abierto, porque
                      // aquí van tres letras solas y a 12 en vez de 13.
                      Text(
                        'BUS',
                        style: AppTextStyles.pie.copyWith(
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.4,
                        ),
                      ),
                      const SizedBox(width: 10),
                      PlacaBus(
                        busPlaca(busId),
                        cajaKey: const ValueKey('hoja-placa'),
                      ),
                    ],
                  ),
                ),
                // El filo que separa quién es de cuánto falta. 8 debajo de la
                // placa y 10 hasta el número: el número trae su propio aire
                // por arriba (alto de línea 0,9), así que 10 se ve como 8.
                const SizedBox(height: 8),
                Container(
                  key: const ValueKey('hoja-filo'),
                  height: 1,
                  color: AppColors.hairline,
                ),
                const SizedBox(height: 10),
                // El alto se anima aquí y no dentro del vaivén: la tarjeta
                // va a media hoja y lo de abajo tiene que deslizarse con su
                // borde. El vaivén de abajo es el pie de la hoja y su alto
                // ya lo anima la hoja; con otro `AnimatedSize` en medio, la
                // hoja llegaba a su alto un cuadro tarde por cada nivel.
                TamanoAnimado(
                  duracion: AppMotion.pausado,
                  alineacion: Alignment.topCenter,
                  child: _Vaiven(
                    animacion: _rueda,
                    haciaRueda: _eleccion != null,
                    // Sin señal, lo de siempre es la otra tarjeta: aquí no
                    // hay nada a lo que volver.
                    normal: staleLabel != null
                        ? const SizedBox(width: double.infinity)
                        : ocupacion == null
                            ? cifra
                            : Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  cifra,
                                  // 10 bajo la unidad, como del filo de
                                  // arriba al número; 14 a los lados para
                                  // que el filo no toque el marco.
                                  const SizedBox(height: 10),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14),
                                    child: OcupacionBus(porcentaje: ocupacion),
                                  ),
                                ],
                              ),
                    rueda: eleccion == null
                        ? null
                        : _preguntaRueda(
                            eleccion, distanciaAvisoHasta(distance)),
                  ),
                ),
              ],
            ),
          ),
          _Vaiven(
            animacion: _rueda,
            haciaRueda: _eleccion != null,
            normal: staleLabel != null
                ? const SizedBox(width: double.infinity)
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _NotaAnimada(stateDetail),
                      const SizedBox(height: 12),
                      _StickyAlertButton(
                        key: widget.alertKey,
                        onBlockedChanged: widget.onGuideAlertBlocked,
                        isActive: isActive,
                        blocked: isActive ? false : blocked,
                        label: alertButtonLabel,
                        onPressed: () => _toggleAlert(
                          busId,
                          reemplazarBusId: activeOtherBusId,
                        ),
                      ),
                      if (filaDistancia != null) filaDistancia,
                    ],
                  ),
            rueda: eleccion == null ? null : _respuestas(eleccion),
          ),
        ],
      ),
    );
    // «Atrás» con la pregunta abierta la cierra sin elegir, como el
    // «Cancelar»: no saca de la app ni deja el aviso a medio armar.
    return PopScope(
      canPop: _eleccion == null,
      onPopInvokedWithResult: (salio, _) {
        if (!salio) _responder(null);
      },
      child: tarjeta,
    );
  }

  /// Lo de dentro de la tarjeta mientras pregunta: el título y la rueda. La
  /// placa se queda arriba: la distancia que se elige es la de este bus.
  /// [hasta] sale del bus de ahora, no del de cuando se abrió: si se acerca
  /// con la rueda abierta, lo que ya pasó deja de ofrecerse y la elegida
  /// baja a la mayor que sirve (dueño, 2026-10-07: «el bus ya va a 2,4 km y
  /// aún puedo poner 2,6 km»).
  Widget _preguntaRueda(_Eleccion eleccion, int? hasta) {
    final desde = eleccion.desde;
    // Si el bus ya pasó lo más cerca que llega la ruta, queda solo [desde].
    if (desde != null && hasta != null && hasta < desde) hasta = desde;
    if (desde != null && eleccion.metros < desde) eleccion.metros = desde;
    if (hasta != null && eleccion.metros > hasta) eleccion.metros = hasta;
    // Por qué la rueda no va de 500 m a 3 km: sin decirlo parece que le
    // faltan distancias. Corto a propósito: con el texto al doble, una
    // línea más larga se parte en dos y la tarjeta deja de caber en un
    // iPhone 13. El porqué entero lo dice el lector.
    final (String? limite, String? limiteHablado) = switch ((desde, hasta)) {
      (null, null) => (null, null),
      (null, final int h) => (
          'Hasta ${distanciaAviso(h)}',
          'Hasta ${distanciaAvisoHablada(h)}: el bus ya está más cerca',
        ),
      (final int d, null) => (
          'Desde ${distanciaAviso(d)}',
          'Desde ${distanciaAvisoHablada(d)}: tu ruta no pasa más cerca',
        ),
      (final int d, final int h) => (
          _rango(d, h),
          'De ${distanciaAvisoHablada(d)} a ${distanciaAvisoHablada(h)}: tu '
              'ruta no pasa más cerca y el bus ya está más cerca',
        ),
    };
    // Sin relleno propio a los lados: la tarjeta ya trae sus 24, y desde
    // que va a lo ancho de la barra (20 menos por lado) los 16 de más
    // partían «0,7 a 1,2 km» en dos líneas con el texto al doble.
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // `subtitulo`, como los títulos de los estados de la hoja; se
        // anuncia como encabezado para que el lector sepa qué pregunta la
        // rueda de abajo.
        Semantics(
          header: true,
          child: Text(
            eleccion.primeraVez
                ? '¿A qué distancia te avisamos?'
                : 'Distancia del aviso',
            textAlign: TextAlign.center,
            style: AppTextStyles.subtitulo,
          ),
        ),
        if (eleccion.avisoActivo) ...[
          const SizedBox(height: 4),
          Text(
            'Solo se cambia la distancia de este aviso',
            textAlign: TextAlign.center,
            style: AppTextStyles.pie.copyWith(color: AppColors.textSecondary),
          ),
        ],
        if (limite != null) ...[
          const SizedBox(height: 4),
          Semantics(
            label: limiteHablado,
            excludeSemantics: true,
            child: Text(
              limite,
              textAlign: TextAlign.center,
              style: AppTextStyles.pie.copyWith(color: AppColors.textSecondary),
            ),
          ),
        ],
        // 8 hasta la rueda: su primera fila es la más tenue, y el aire
        // que se ve ya es mayor.
        const SizedBox(height: 8),
        RuedaDistancia(
          inicial: eleccion.metros,
          desde: desde,
          hasta: hasta,
          alCambiar: (metros) => eleccion.metros = metros,
        ),
      ],
    );
  }

  /// «1,5 a 2,2 km», con la unidad una vez, sin raya (dueño, 2026-10-18):
  /// «De 1,5 km a 2,2 km» con el texto al doble se parte en dos líneas y la
  /// tarjeta deja de caber en un iPhone 13. Si solo la punta de arriba
  /// llega al kilómetro, la de abajo también va en km («0,7 a 1,2 km»):
  /// «700 m a 1,2 km» tampoco cabe. Las dos son múltiplos de 100 m.
  static String _rango(int desde, int hasta) {
    final a = distanciaAviso(hasta);
    final enKm = a.endsWith(' km');
    final de = enKm
        ? (desde / 1000).toStringAsFixed(1).replaceAll('.', ',')
        : distanciaAviso(desde).replaceAll(' m', '');
    return '$de a $a';
  }

  /// Lo de debajo de la tarjeta mientras pregunta: «Guardar» en el sitio y
  /// con la forma del botón del aviso, que es el que el pulgar acaba de
  /// tocar, y debajo «Solo esta vez» (o «Cancelar», si es «Cambiar») como
  /// texto, con su alto de 48.
  Widget _respuestas(_Eleccion eleccion) {
    final forma = WidgetStateProperty.all(
      const StadiumBorder(),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primaryAccessible,
              foregroundColor: Colors.white,
              textStyle: AppTextStyles.boton,
              // 60, el alto del botón del aviso: «Guardar» ocupa su sitio
              // y la hoja no se mueve bajo el pulgar.
              minimumSize: const Size.fromHeight(60),
            ).copyWith(shape: forma),
            onPressed: () =>
                _responder((metros: eleccion.metros, guardar: true)),
            child: const Text('Guardar'),
          ),
        ),
        const SizedBox(height: 4),
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: AppColors.textSecondary,
            textStyle: AppTextStyles.boton,
            minimumSize: const Size(48, 48),
          ).copyWith(shape: forma),
          onPressed: eleccion.primeraVez
              ? () => _responder((metros: eleccion.metros, guardar: false))
              : () => _responder(null),
          child: Text(eleccion.primeraVez ? 'Solo esta vez' : 'Cancelar'),
        ),
      ],
    );
  }
}

/// Una pregunta de la distancia en curso. [metros] sigue a la rueda.
class _Eleccion {
  _Eleccion(this.busId, this.metros,
      {this.desde, required this.primeraVez, required this.avisoActivo});

  final String busId;
  int metros;

  /// La menor que alcanza la ruta. La ruta no se mueve con la rueda
  /// abierta: se fija al abrirla.
  final int? desde;
  final bool primeraVez;
  final bool avisoActivo;
  final respuesta = Completer<({int metros, bool guardar})?>();
}

/// Pasa de [normal] a [rueda] y de vuelta, con el mismo fundido encadenado
/// que el resto de la hoja: lo que se va se apaga en el primer 40 % y lo
/// que llega entra desde el 30 %. El alto salta al del que llega; quien lo
/// anima es el `AnimatedSize` de afuera.
///
/// No es un `AnimatedSwitcher` porque [normal] lleva las llaves globales
/// de la guía (botón del aviso, número): con «Guardar» tocado antes de que
/// lo de siempre terminara de irse, el switcher montaba dos copias a la
/// vez. Aquí cada uno tiene su sitio fijo y existe una sola vez.
class _Vaiven extends StatelessWidget {
  const _Vaiven({
    required this.animacion,
    required this.haciaRueda,
    required this.normal,
    required this.rueda,
  });

  /// 0, [normal]; 1, [rueda].
  final Animation<double> animacion;

  /// Hacia dónde va: decide cuál entra y cuál sale.
  final bool haciaRueda;
  final Widget normal;

  /// `null` cuando no hay pregunta que mostrar.
  final Widget? rueda;

  static const _entra = Interval(0.3, 1, curve: AppMotion.curvaEntrada);
  static const _sale = Interval(0.6, 1, curve: AppMotion.curvaSalida);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animacion,
      builder: (context, _) {
        final v = animacion.value;
        final rueda = this.rueda;
        // El que llega está desde el primer cuadro, aunque todavía no se
        // vea: es el que le da el alto a todo.
        final conNormal = rueda == null || !haciaRueda || v < 1;
        final conRueda = rueda != null && (haciaRueda || v > 0);
        final opacidadRueda =
            haciaRueda ? _entra.transform(v) : _sale.transform(v);
        final opacidadNormal =
            haciaRueda ? _sale.transform(1 - v) : _entra.transform(1 - v);
        // El que va de salida se posiciona: no cuenta en el alto, que
        // viaja directo al del que llega.
        Widget lugar(Widget hijo, String llave, double opacidad,
                {required bool llega}) =>
            Positioned(
              key: ValueKey(llave),
              top: llega ? null : 0,
              left: llega ? null : 0,
              right: llega ? null : 0,
              child: IgnorePointer(
                ignoring: !llega,
                child: ExcludeSemantics(
                  excluding: !llega,
                  child: Opacity(opacity: opacidad, child: hijo),
                ),
              ),
            );
        return Stack(
          alignment: Alignment.topCenter,
          children: [
            if (conNormal)
              lugar(normal, 'vaiven-normal', rueda == null ? 1 : opacidadNormal,
                  llega: !haciaRueda || rueda == null),
            if (conRueda)
              lugar(rueda, 'vaiven-rueda', opacidadRueda, llega: haciaRueda),
          ],
        );
      },
    );
  }
}

/// V1: verde lejos, ámbar acercándose, coral ya casi. El ámbar empieza en
/// [radio], la distancia a la que suena el aviso: el color cambia justo
/// cuando el aviso lo dice.
///
/// Van las variantes accesibles del semáforo, no las de relleno: este
/// color pinta el número de 64 en peso 200, que es el trazo más fino de
/// toda la app y lo único que la app existe para decir. Los tres de
/// relleno se quedaban en 2,9:1 sobre la arena de antes, por debajo del 3:1 que
/// pide la norma hasta para un icono; estos tres dan 5:1 y, entre
/// ellos, el mismo 5:1, así que ninguna distancia se lee más pesada que
/// otra por culpa del color. Público para probar los bordes exactos.
Color colorDeDistancia(double meters, int radio) {
  if (meters < 300) return AppColors.coralAccessible;
  if (meters < radio) return AppColors.warningAccessible;
  return AppColors.primaryAccessible;
}

/// Lo que la hoja explica bajo la distancia: un ícono y una frase.
///
/// El tono lo decide el constructor, no quien la pinta, para que la misma
/// clase de situación lleve siempre el mismo color.
class _Nota {
  /// Algo impide el aviso (la ruta no pasa cerca): el coral del semáforo.
  const _Nota.impide(this.icono, this.texto)
      : fondo = AppColors.coralLight,
        tinta = AppColors.coralAccessible,
        metros = null,
        onTap = null;

  /// Solo falta un paso o un dato: la tinta, sin alarma.
  const _Nota.paso(this.icono, this.texto)
      : fondo = AppColors.surfaceMuted,
        tinta = AppColors.primaryDeep,
        metros = null,
        onTap = null;

  /// La distancia del aviso puesto, con su «Cambiar»: el verde del aviso y
  /// su campana, porque dice cuándo va a sonar.
  _Nota.distancia(int this.metros, VoidCallback this.onTap)
      : icono = Icons.notifications_active_outlined,
        texto = 'Te avisamos a ${distanciaAviso(metros)}',
        fondo = AppColors.primaryTint,
        tinta = AppColors.primaryAccessible;

  final IconData icono;
  final String texto;
  final Color fondo;
  final Color tinta;

  /// Solo en la nota de la distancia: la que se dice y qué hace el toque.
  final int? metros;
  final VoidCallback? onTap;
}

/// La nota entra, sale o cambia sin salto.
///
/// Al llevar el pin hasta la ruta, la nota «La ruta no pasa cerca…»
/// desaparecía de un cuadro al siguiente y el botón subía de golpe (dueño,
/// 2026-09-30). Ahora el hueco se cierra con la misma curva y duración con
/// las que la hoja cambia de alto, y la nota se funde mientras tanto: lo
/// que el ojo sigue es el botón, y el botón se desliza.
class _NotaAnimada extends StatelessWidget {
  const _NotaAnimada(this.nota);

  final _Nota? nota;

  @override
  Widget build(BuildContext context) {
    final duracion = AppMotion.duracion(context, AppMotion.pausado);
    final nota = this.nota;
    return TamanoAnimado(
      duracion: AppMotion.pausado,
      alineacion: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: duracion,
        // El mismo fundido encadenado que el contenido de la hoja: la nota
        // vieja se apaga en el primer 40 % y la nueva entra desde el 30 %,
        // para que dos frases no se lean una encima de la otra.
        switchInCurve: const Interval(0.3, 1, curve: AppMotion.curvaEntrada),
        switchOutCurve: const Interval(0.6, 1, curve: AppMotion.curvaSalida),
        // Lo que sale no cuenta en el alto: así el hueco viaja directo al
        // de la nota nueva (o a cero) en vez de esperar a que la vieja
        // termine de irse.
        layoutBuilder: (actual, anteriores) => Stack(
          alignment: Alignment.topCenter,
          children: [
            for (final anterior in anteriores)
              Positioned(top: 0, left: 0, right: 0, child: anterior),
            if (actual != null) actual,
          ],
        ),
        child: nota == null
            ? const SizedBox(
                key: ValueKey('hoja-sin-nota'), width: double.infinity)
            : Padding(
                key: ValueKey(nota.texto),
                // 14 entre la tarjeta y la nota; viaja con ella, así que sin
                // nota tampoco queda aire de más.
                padding: const EdgeInsets.only(top: 14),
                child: _NotaHoja(nota),
              ),
      ),
    );
  }
}

/// La nota blanca con su ícono en baldosa (diseño «A», dueño 2026-09-30).
///
/// Blanca sobre la hoja blanca, con el filo de siempre y la sombra suave
/// de las filas del selector, que es la que la despega. 16 de radio
/// (`AppRadius.lg`) para que case con el botón de abajo; 10×12 de relleno
/// para que la baldosa de 30 quede a la misma distancia del borde por
/// arriba y por la izquierda una vez sumado el aire de la línea.
class _NotaHoja extends StatelessWidget {
  const _NotaHoja(this.nota);

  final _Nota nota;

  @override
  Widget build(BuildContext context) {
    final onTap = nota.onTap;
    final metros = nota.metros;
    final contenido = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          // Baldosa de 30 con el glifo de 18: el mismo par tinte/tinta de
          // los medallones de los estados vacíos, que ya pasa los 3:1
          // (ya_viene_core/test/contraste_test.dart). El ícono no se lee:
          // la frase de al lado ya lo dice todo.
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: nota.fondo,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(nota.icono, size: 18, color: nota.tinta),
          ),
          const SizedBox(width: 10),
          // `pie` (12) en el gris de cuerpo y no en el secundario: es letra
          // chica, y la nota solo sirve si se lee a la primera.
          Expanded(
            child: Text(
              nota.texto,
              style: AppTextStyles.pie.copyWith(color: AppColors.textBody),
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 10),
            const _PildoraCambiar(),
          ],
        ],
      ),
    );
    final hoja = Container(
      key: const ValueKey('hoja-nota'),
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.hairline),
        boxShadow: AppShadows.soft,
      ),
      child: onTap == null
          ? contenido
          // La nota entera es el blanco del toque: 30 de baldosa más 10 y
          // 10 de relleno (y el filo) dan 52, por encima de los 48 del
          // pulgar. El material transparente lleva la onda sobre el blanco.
          : Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(AppRadius.lg - 1),
                child: contenido,
              ),
            ),
    );
    if (onTap == null || metros == null) return hoja;
    return Semantics(
      key: const ValueKey('cambiar-distancia'),
      button: true,
      // La misma frase que la fila de Android, con la distancia en palabras.
      label: 'Te avisamos a ${distanciaAvisoHablada(metros)}. '
          'Cambiar la distancia',
      excludeSemantics: true,
      onTap: onTap,
      child: hoja,
    );
  }
}

/// «Te avisamos a 1,8 km · Cambiar», bajo el botón del aviso.
///
/// Una línea de texto y no un segundo botón: el botón grande es lo que se
/// hace en esta hoja, y la distancia es un ajuste suyo. El toque abarca la
/// fila entera con 48 de alto, el mínimo de un blanco para el pulgar. Gris
/// secundario (5,4:1 sobre el blanco de la hoja) para lo que se dice y la
/// píldora de «Cambiar» para lo que se toca.
class _CambiarDistancia extends StatelessWidget {
  const _CambiarDistancia({required this.metros, required this.onTap});

  final int metros;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: const ValueKey('cambiar-distancia'),
      button: true,
      // Una sola frase para la voz, con la distancia en palabras.
      label: 'Te avisamos a ${distanciaAvisoHablada(metros)}. '
          'Cambiar la distancia',
      excludeSemantics: true,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  runAlignment: WrapAlignment.center,
                  spacing: 6,
                  children: [
                    Text(
                      'Te avisamos a ${distanciaAviso(metros)}',
                      style: AppTextStyles.etiqueta
                          .copyWith(color: AppColors.textSecondary),
                    ),
                    const _PildoraCambiar(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// «Cambiar», con la cara de «Quitar» en la píldora de la ubicación
/// (`PildoraEstado` con `actionDanger`: gris apagado, filo y píldora) pero
/// con la letra roja (dueño, 2026-10-06). `coralAccessible` y no `coral`:
/// sobre `surfaceMuted` da 5,0:1, y el coral a secas no llega a 3.
///
/// Solo se ve: el toque es de la nota o de la fila entera, que miden los
/// 48 del pulgar y la píldora no.
class _PildoraCambiar extends StatelessWidget {
  const _PildoraCambiar();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Text(
        'Cambiar',
        style:
            AppTextStyles.etiqueta.copyWith(color: AppColors.coralAccessible),
      ),
    );
  }
}

class _StickyAlertButton extends StatefulWidget {
  final bool isActive;

  /// Bus ya dentro del radio de aviso: el botón se pinta gris (bloqueado).
  final bool blocked;
  final String label;
  final VoidCallback onPressed;
  final ValueChanged<bool>? onBlockedChanged;

  const _StickyAlertButton({
    super.key,
    required this.isActive,
    this.blocked = false,
    required this.label,
    required this.onPressed,
    this.onBlockedChanged,
  });

  @override
  State<_StickyAlertButton> createState() => _StickyAlertButtonState();
}

class _StickyAlertButtonState extends State<_StickyAlertButton> {
  bool _isPressed = false;
  bool? _reportedBlocked;

  @override
  void initState() {
    super.initState();
    _reportBlocked();
  }

  @override
  void didUpdateWidget(covariant _StickyAlertButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    _reportBlocked();
  }

  void _reportBlocked() {
    if (_reportedBlocked == widget.blocked) return;
    final blocked = widget.blocked;
    _reportedBlocked = blocked;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onBlockedChanged?.call(blocked);
    });
  }

  void _activar() {
    HapticFeedback.mediumImpact();
    widget.onPressed();
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = widget.blocked
        ? AppColors.textSecondary
        : widget.isActive
            ? const Color(0xFF065F46)
            : AppColors.primaryAccessible;

    return Semantics(
      button: true,
      // Bloqueado no es lo mismo que ausente: el botón sigue ahí y su
      // rótulo dice por qué no se puede tocar ("El bus ya está cerca").
      // Anunciarlo deshabilitado es lo que evita que alguien lo toque tres
      // veces esperando respuesta.
      enabled: !widget.blocked,
      label: widget.label,
      // El toque va aquí arriba además de en el gesto: `excludeSemantics`
      // tapa el árbol de abajo entero, y con él la acción del
      // GestureDetector. Sin esta línea el botón se anuncia pero el doble
      // toque de VoiceOver no lo activa.
      onTap: widget.blocked ? null : _activar,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () {
          // Un botón bloqueado (por histéresis) no debe poder armar el aviso
          // aunque el bus ya no esté dentro del radio: el estado visual y la
          // guía dependen de ese bloqueo.
          if (widget.blocked) return;
          _activar();
        },
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapCancel: () => setState(() => _isPressed = false),
        onTapUp: (_) => setState(() => _isPressed = false),
        child: AnimatedScale(
          scale: _isPressed ? 0.96 : 1,
          duration: AppMotion.instante,
          // Sin rebote, aunque este es el botón principal de la app: el
          // drawer y la guía ya quitaron el suyo (`easeOutBack` se pasa de
          // tamaño y vuelve), y aquí baja al 96 % y regresa con la misma
          // curva de entrada que el resto.
          curve: AppMotion.curvaEntrada,
          child: AnimatedContainer(
            duration: AppMotion.normal,
            curve: AppMotion.curvaEntrada,
            width: double.infinity,
            // 52 y no 60 (dueño, 2026-10-27, más mapa): sigue por encima
            // de los 44 de Apple y el círculo de 30 conserva 11 de aire.
            height: 52,
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              boxShadow: [
                BoxShadow(
                  color: backgroundColor.withValues(alpha: 0.24),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: AnimatedSwitcher(
              duration: AppMotion.rapido,
              switchInCurve: AppMotion.curvaEntrada,
              switchOutCurve: AppMotion.curvaSalida,
              child: Row(
                key: ValueKey('${widget.isActive}-${widget.blocked}'),
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Botón-en-botón: el icono vive en su propio círculo
                  // blanco translúcido, a ras del texto —igual que los
                  // primarios de la landing. El botón no se mueve; el
                  // círculo es lo que se lee como control.
                  Container(
                    width: 30,
                    height: 30,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0x2EFFFFFF),
                    ),
                    child: Icon(
                      widget.blocked
                          ? Icons.notifications_off_outlined
                          : widget.isActive
                              ? Icons.check_circle_rounded
                              : Icons.notifications_active_outlined,
                      color: Colors.white,
                      size: 17,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      widget.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      // Caja normal, no versalitas. "AVISARME CUANDO ESTÉ
                      // CERCA" era una frase entera de 26 letras gritada en
                      // mayúsculas: la guía de Apple no las usa en botones, y
                      // en español además se leen más lento. El interletrado
                      // abierto existía para sostener las versalitas; en caja
                      // normal solo separa las letras.
                      style: AppTextStyles.boton.copyWith(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String? _staleLabel(BusPosition? bus) {
  if (bus == null || !bus.isGhostBus) return null;
  final minutes = DateTime.now().difference(bus.timestamp).inMinutes;
  if (minutes < 1) return 'Sin señal ahora mismo';
  if (minutes == 1) return 'Sin señal desde hace 1 min';
  if (minutes < 60) return 'Sin señal desde hace $minutes min';
  final hours = minutes ~/ 60;
  return 'Sin señal desde hace $hours h';
}

/// Un estado vacío que además es un botón: se anuncia como uno (título y
/// frase juntos, como los demás estados) y se hunde un poco al tocarlo, como
/// las tarjetas del selector, para que el dedo sepa que acertó.
class _EstadoTocable extends StatefulWidget {
  const _EstadoTocable({super.key, required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  State<_EstadoTocable> createState() => _EstadoTocableState();
}

class _EstadoTocableState extends State<_EstadoTocable> {
  bool _hundido = false;

  void _hundir(bool valor) {
    if (_hundido != valor) setState(() => _hundido = valor);
  }

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Semantics(
        button: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => _hundir(true),
          onTapUp: (_) => _hundir(false),
          onTapCancel: () => _hundir(false),
          onTap: widget.onTap,
          // 0.975: lo mismo que se hunden las tarjetas del selector, al
          // que este bloque lleva; con su tiempo y su curva.
          child: AnimatedScale(
            scale: _hundido ? 0.975 : 1,
            duration: AppMotion.duracion(context, AppMotion.instante),
            curve: AppMotion.curvaEntrada,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
