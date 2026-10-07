import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

import '../../../../core/utils/bus_labels.dart';
import '../../../../core/utils/distancia.dart';
import '../../../../core/widgets/aviso.dart';
import '../../../../core/widgets/cifra_viva.dart';
import '../../../../core/widgets/dialogo.dart';
import '../../../../core/widgets/placa_bus.dart';
import '../../../../core/widgets/sheet_handle.dart';
import '../../../../core/widgets/sheet_top_border.dart';
import '../../../notifications/presentation/providers/distancia_aviso_provider.dart';
import '../../../notifications/presentation/providers/proximity_alerts_provider.dart';
import '../providers/alert_toggle_provider.dart';
import '../providers/map_view_state.dart';
import '../providers/route_reach_provider.dart';
import '../providers/tracking_providers.dart';
import '../providers/user_location_provider.dart';
import '../utils/geo.dart';
import 'map_recenter_button.dart';
import 'rueda_distancia.dart';
import 'sena_tocar_bus.dart';

class EtaBottomSheet extends ConsumerStatefulWidget {
  const EtaBottomSheet({
    super.key,
    this.alertKey,
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
  static const double _expandedMapInset = 250;
  static const double _collapsedMapInset = 120;

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
    // Refresca el texto "Sin señal · hace X min" de un bus fantasma: sin
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
  Future<void> _toggleAlert(String busId) async {
    final result = await ref
        .read(alertToggleProvider)
        .toggle(busId, elegirDistancia: () => _preguntarDistancia(busId));
    // Cerró la rueda sin elegir (cancelled): sin háptico ni mensaje, no
    // hay nada que decirle.
    if (!mounted) return;
    if (result.needsHaptic) HapticFeedback.mediumImpact();
    final message = result.message;
    if (message != null) {
      mostrarAviso(context, message);
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

  /// Distancia en metros del punto de espera al bus; null si no se puede
  /// medir.
  ///
  /// Un bus con aviso armado se mide desde el pin con el que se armó, no
  /// desde el pin de ahora: es la misma referencia que usa el aviso para
  /// decidir cuándo sonar, y verla cambiar al mover el pin hacía creer que el
  /// aviso se había mudado con él.
  double? _distanceToBus(BusPosition? bus) {
    if (bus == null) return null;
    final ancla =
        ref.read(proximityAlertsProvider.notifier).anchorFor(bus.busId);
    if (ancla != null) {
      return haversineMeters(ancla.$1, ancla.$2, bus.lat, bus.lon);
    }
    final location = ref.read(userLocationProvider);
    if (!location.hasPosition) return null;
    return haversineMeters(location.lat!, location.lon!, bus.lat, bus.lon);
  }

  /// A qué distancia sonaría el aviso de [busId]: la del aviso que ya suena
  /// (puede ser de «Solo esta vez»), si no la guardada y, sin ninguna, el
  /// kilómetro donde arranca la rueda. Es la que dice la fila «Cambiar» y la
  /// que parte el color de la cifra.
  int _radioDe(String busId) =>
      ref.read(proximityAlertsProvider.notifier).radioDe(busId) ??
      ref.watch(distanciaAvisoProvider) ??
      distanciaAvisoInicial;

  /// Dentro de qué distancia el bus ya está demasiado cerca para armar el
  /// aviso: la guardada o, sin ninguna, la menor de la rueda —con el bus a
  /// 800 m todavía se puede pedir el aviso de 500 m—. Es la misma cuenta
  /// que hace [AlertToggleController] antes de abrir la rueda.
  int get _radioBloqueo =>
      ref.watch(distanciaAvisoProvider) ?? distanciaAvisoMinima;

  /// El bus ya está dentro del radio de aviso: no se puede activar la alerta.
  bool _busAlreadyNear(BusPosition? bus) {
    final distance = _distanceToBus(bus);
    return distance != null && distance <= _radioBloqueo;
  }

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
        distance > _radioBloqueo + margenRearmeMetros) {
      _blockedLatched = false;
    }
    return _blockedLatched;
  }

  /// Pregunta a qué distancia avisar en la misma tarjeta del bus, sin
  /// ventana encima (dueño, 2026-10-06: «que salga en la misma card en vez
  /// de un popup nuevo»). [primeraVez]: al activar el primer aviso, con
  /// «Guardar» y «Solo esta vez». Si no, es «Cambiar», con «Guardar» y
  /// «Cancelar». `null` si se fue sin elegir: «Cancelar», «atrás» o soltar
  /// el bus.
  Future<({int metros, bool guardar})?> _preguntarDistancia(
    String busId, {
    int inicial = distanciaAvisoInicial,
    bool primeraVez = true,
    bool avisoActivo = false,
  }) {
    // El aviso valida la ruta antes de preguntar: en esa espera la hoja
    // pudo irse.
    if (!mounted) return Future.value();
    _responder(null);
    final eleccion = _Eleccion(busId, distanciaEnRueda(inicial),
        primeraVez: primeraVez, avisoActivo: avisoActivo);
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
  /// y, si este bus tiene el aviso puesto, el aviso pasa a sonar ahí
  /// (dueño, 2026-10-06: «cambia también el activo»).
  Future<void> _cambiarDistancia(String busId, int actual) async {
    final elegida = await _preguntarDistancia(
      busId,
      inicial: actual,
      primeraVez: false,
      avisoActivo: ref.read(activeAlertsProvider).contains(busId),
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

  void _publishMapInset([double? forcedInset]) {
    final defaultInset = _abierta ? _expandedMapInset : _collapsedMapInset;
    final inset = forcedInset ?? defaultInset;
    if (_lastPublishedInset == inset) return;
    _lastPublishedInset = inset;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
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
          next.mode == UserLocationMode.gpsFailed;
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
      _publishMapInset(0);
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
              Padding(
                padding: const EdgeInsets.only(
                  right: AppSpacing.md,
                  bottom: AppSpacing.sm,
                ),
                child: MapRecenterButton(key: widget.recenterKey),
              ),
              _sheetBody(child: child, toggleable: toggleable),
            ],
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
    return GestureDetector(
      // El dedo manda: la hoja baja y sube pegada al pulgar, y al soltar
      // termina sola el camino que falte.
      onVerticalDragStart: toggleable ? _arrastreEmpieza : null,
      onVerticalDragUpdate: toggleable ? _arrastreSigue : null,
      onVerticalDragEnd: toggleable ? _arrastreTermina : null,
      child: Container(
        key: widget.detailKey,
        width: double.infinity,
        // Un filo de un pixel separa la hoja del mapa mejor que una sombra
        // ancha: la sombra sobre un mapa lleno de color se lee como
        // suciedad, el filo se lee como borde. Solo arriba: la hoja va
        // pegada al borde de abajo y ocupa todo el ancho, y un filo
        // completo bajaba por los dos cantos de la pantalla.
        decoration: ShapeDecoration(
          color: AppColors.arena,
          shape: const SheetTopBorder(
            side: BorderSide(color: AppColors.hairline),
          ),
          shadows: [
            BoxShadow(
              color: AppColors.primaryDeep.withValues(alpha: 0.06),
              blurRadius: 20,
              offset: const Offset(0, -4),
            )
          ],
        ),
        child: SafeArea(
          top: false,
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
                        // Plegada, el asa es lo único que queda: se le deja el
                        // mismo aire arriba y abajo para que no parezca un
                        // resto de la tarjeta, sino un control.
                        padding:
                            EdgeInsets.only(top: 14, bottom: 14 + 4 * abierta),
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
                    // siguiente al alto de la tarjeta —y al soltarlo, al del
                    // estado vacío—, y el fundido de dentro no lo
                    // disimulaba: lo que el ojo sigue es el borde de arriba.
                    child: AnimatedSize(
                      duration: AppMotion.duracion(context, AppMotion.pausado),
                      curve: AppMotion.curvaCambio,
                      alignment: Alignment.topCenter,
                      child: AnimatedSwitcher(
                        duration:
                            AppMotion.duracion(context, AppMotion.pausado),
                        // Fundido encadenado: lo viejo se apaga en el primer
                        // 40 % y lo nuevo entra a partir del 30 %. Cruzados a
                        // la vez, el número del bus y el texto del estado
                        // vacío se leían uno encima del otro a medio cambio.
                        switchInCurve: const Interval(0.3, 1,
                            curve: AppMotion.curvaEntrada),
                        switchOutCurve: const Interval(0.6, 1,
                            curve: AppMotion.curvaSalida),
                        // El contenido entrante y el saliente se apilan por su
                        // borde superior, que es el que no se mueve: apilados
                        // por el centro (lo que hace por defecto) el texto
                        // saltaba hacia arriba mientras la hoja todavía bajaba.
                        //
                        // Lo que sale va posicionado para que no cuente en el
                        // alto: así el tamaño viaja directo al del contenido
                        // nuevo en vez de esperar a que el viejo termine de
                        // irse. Y sin recorte, porque el viejo puede ser más
                        // alto que el alto que ya está menguando.
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
                        transitionBuilder: (child, animation) => FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              // Un dedo de recorrido, no más: acompaña al
                              // pliegue en vez de competir con él.
                              begin: Offset(
                                  0, 0.06 * AppMotion.desplazamiento(context)),
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
        ),
      ),
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
    final routeTooFar = routeDistance != null &&
        routeDistance > ref.watch(distanciaMaximaDeRutaProvider);

    final String stateKey;
    final String title;
    final String subtitle;
    final IconData icon;
    Widget? dibujo;
    if (!hasPosition) {
      stateKey = 'empty-no-position';
      title = 'Toca el mapa para indicar dónde estás';
      // Lo de arrastrar el pin ya no se dice aquí: esta frase solo se ve
      // mientras NO hay pin, o sea desaparecía justo cuando se volvía
      // cierta. Vive en la píldora de estado, junto al pin.
      subtitle = 'Ahí ponemos tu punto de espera y medimos desde él';
      icon = Icons.touch_app_outlined;
    } else if (route == null) {
      stateKey = 'empty-no-route';
      title = 'Escoge empresa y ruta';
      // «Aquí» y no «la barra de arriba»: el bloque entero abre el
      // selector, porque ahí es donde la gente tocaba (dueño, 2026-09-28).
      subtitle = 'Toca aquí para elegir la empresa y su ruta';
      icon = Icons.route_outlined;
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
        // el de la píldora de ubicación: suelto sobre la arena era un glifo
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
    final isActive = ref.watch(activeAlertsProvider).contains(busId);
    final locationState = ref.watch(userLocationProvider);
    final staleLabel = _staleLabel(bus);
    final ghostBlocked = !isActive && bus != null && bus.isGhostBus;
    final distance = _distanceToBus(bus);
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
    final alreadyNear = !isActive && _busAlreadyNear(bus);
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
    void cambiar() => _cambiarDistancia(busId, radio);
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
          Text("$busLabel · conserva su última posición",
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
                  label: isActive ? "Aviso activado" : "Bus sin señal",
                  onPressed: () => _toggleAlert(busId),
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
            : const _Nota.aviso(Icons.info_outline_rounded,
                "Puedes cambiar de aplicación; no cierres Ya Viene del todo")
        : !locationState.hasPosition
            ? const _Nota.paso(Icons.touch_app_outlined,
                "Toca el mapa para indicar dónde estás")
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
        mainAxisSize: MainAxisSize.min,
        children: [
          // Sin franja de color arriba (diseño «A», dueño 2026-09-30): el
          // número ya lleva la urgencia en su color y la franja la repetía.
          // Los 18 que la separaban del título pasan a 12: sin franja, el
          // asa de la hoja queda justo encima y no hace falta más aire.
          const SizedBox(height: 12),
          // Quién es y cuánto falta, en una tarjeta con marco (prueba del
          // dueño, 2026-09-30): blanca con el filo de las tarjetas del
          // selector, sin sombra por lo mismo que ellas —sobre la arena una
          // sombra azulada se lee como banda gris—. [AppRadius.card] y no
          // `lg`: mide casi 200 de alto, y 16 en una caja así se ve recto.
          // La nota y el botón van fuera: son lo que la app dice y lo que
          // se hace, no lo que se mira.
          Container(
            key: const ValueKey('hoja-tarjeta'),
            width: double.infinity,
            // 14 arriba y 18 abajo: la unidad de 15 no trae aire propio
            // debajo, y con 14 quedaba más pegada al marco que la placa.
            padding: const EdgeInsets.only(top: 14, bottom: 18),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: AppColors.hairline),
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
                // El filo que separa quién es de cuánto falta. 10 debajo de la
                // placa y 14 hasta el número: el número de 64 trae su propio
                // aire por arriba (alto de línea 0,9), así que 14 se ve como
                // 10.
                const SizedBox(height: 10),
                Container(
                  key: const ValueKey('hoja-filo'),
                  height: 1,
                  color: AppColors.hairline,
                ),
                const SizedBox(height: 14),
                // El alto se anima aquí y no dentro del vaivén: la tarjeta
                // va a media hoja y lo de abajo tiene que deslizarse con su
                // borde. El vaivén de abajo es el pie de la hoja y su alto
                // ya lo anima la hoja; con otro `AnimatedSize` en medio, la
                // hoja llegaba a su alto un cuadro tarde por cada nivel.
                AnimatedSize(
                  duration: AppMotion.duracion(context, AppMotion.pausado),
                  curve: AppMotion.curvaCambio,
                  alignment: Alignment.topCenter,
                  child: _Vaiven(
                    animacion: _rueda,
                    haciaRueda: _eleccion != null,
                    // Sin señal, lo de siempre es la otra tarjeta: aquí no
                    // hay nada a lo que volver.
                    normal: staleLabel != null
                        ? const SizedBox(width: double.infinity)
                        : cifra,
                    rueda: eleccion == null ? null : _preguntaRueda(eleccion),
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
                      const SizedBox(height: 18),
                      _StickyAlertButton(
                        key: widget.alertKey,
                        onBlockedChanged: widget.onGuideAlertBlocked,
                        isActive: isActive,
                        blocked: isActive ? false : blocked,
                        label: isActive
                            ? "Aviso activado"
                            : ghostBlocked
                                ? "Bus sin señal"
                                : routeTooFar
                                    ? "Esta ruta no pasa cerca"
                                    : blocked
                                        ? "El bus ya está cerca"
                                        : "Avisarme cuando esté cerca",
                        onPressed: () => _toggleAlert(busId),
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
  Widget _preguntaRueda(_Eleccion eleccion) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Column(
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
              'También cambia el aviso que tienes activo',
              textAlign: TextAlign.center,
              style: AppTextStyles.pie.copyWith(color: AppColors.textSecondary),
            ),
          ],
          // 8 hasta la rueda: su primera fila es la más tenue, y el aire
          // que se ve ya es mayor.
          const SizedBox(height: 8),
          RuedaDistancia(
            inicial: eleccion.metros,
            alCambiar: (metros) => eleccion.metros = metros,
          ),
        ],
      ),
    );
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
      {required this.primeraVez, required this.avisoActivo});

  final String busId;
  int metros;
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
/// relleno se quedaban en 2,9:1 sobre la arena, por debajo del 3:1 que
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

  /// El aviso está puesto y esto es cómo cuidarlo: el verde de la marca.
  const _Nota.aviso(this.icono, this.texto)
      : fondo = AppColors.primaryTint,
        tinta = AppColors.primaryAccessible,
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
    return AnimatedSize(
      duration: duracion,
      curve: AppMotion.curvaCambio,
      alignment: Alignment.topCenter,
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
/// Blanca sobre la arena de la hoja y con el filo de siempre: se despega
/// sin sombra, como las filas del selector. 16 de radio (`AppRadius.lg`)
/// para que case con el botón de abajo; 10×12 de relleno para que la
/// baldosa de 30 quede a la misma distancia del borde por arriba y por la
/// izquierda una vez sumado el aire de la línea.
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
/// secundario (5,0:1 sobre la arena) para lo que se dice y la píldora de
/// «Cambiar» para lo que se toca.
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
            height: 60,
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
  if (minutes == 1) return 'Sin señal · hace 1 min';
  if (minutes < 60) return 'Sin señal · hace $minutes min';
  final hours = minutes ~/ 60;
  return 'Sin señal · hace $hours h';
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
