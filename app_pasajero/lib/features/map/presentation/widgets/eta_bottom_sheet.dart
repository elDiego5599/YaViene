import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

import '../../../../core/utils/bus_labels.dart';
import '../../../../core/widgets/sheet_handle.dart';
import '../../../../core/widgets/sheet_top_border.dart';
import '../../../notifications/presentation/providers/proximity_alerts_provider.dart';
import '../providers/alert_toggle_provider.dart';
import '../providers/map_view_state.dart';
import '../providers/route_reach_provider.dart';
import '../providers/tracking_providers.dart';
import '../providers/user_location_provider.dart';
import '../utils/geo.dart';
import 'alert_guards.dart' show kmLabel;
import 'map_recenter_button.dart';

class EtaBottomSheet extends ConsumerStatefulWidget {
  const EtaBottomSheet({
    super.key,
    this.alertKey,
    this.metricKey,
    this.metricUnitKey,
    this.detailKey,
    this.recenterKey,
    this.onGuideAlertBlocked,
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

  /// Si la app habla con el respaldo (T2.3): la hoja lo dice en una línea
  /// discreta. Lo pasa el mapa desde `enRespaldoProvider`; la hoja no lee la
  /// configuración del backend por su cuenta, así que montarla en una prueba
  /// no pide backend.
  final bool enRespaldo;

  @override
  ConsumerState<EtaBottomSheet> createState() => _EtaBottomSheetState();
}

class _EtaBottomSheetState extends ConsumerState<EtaBottomSheet>
    with SingleTickerProviderStateMixin {
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
  /// dentro del radio), permanece bloqueado hasta que el bus se aleje más de
  /// `alertReArmMeters`. Evita que el cruce de umbrales por el movimiento del
  /// bus haga flapear el botón (y la guía) entre bloqueado/desbloqueado.
  bool _blockedLatched = false;
  String? _latchedBusId;

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
    // Refresca el texto "Sin señal · hace X min" de un bus fantasma: sin
    // posiciones nuevas la UI no se reconstruye sola.
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
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
  /// [alertToggleProvider]; aquí solo se traduce el resultado a háptico y
  /// snackbar.
  Future<void> _toggleAlert(String busId) async {
    final result = await ref.read(alertToggleProvider).toggle(busId);
    if (!mounted) return;
    if (result.needsHaptic) HapticFeedback.mediumImpact();
    final message = result.message;
    if (message != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(message),
      ));
      return;
    }
    if (result.outcome == AlertToggleOutcome.permissionDenied) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content:
            Text('Activa las notificaciones para recibir el aviso del bus'),
        action: SnackBarAction(
          label: 'Ajustes',
          onPressed: openAppSettings,
        ),
      ));
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

  /// El bus ya está dentro del radio de aviso: no se puede activar la alerta.
  bool _busAlreadyNear(BusPosition? bus) {
    final distance = _distanceToBus(bus);
    return distance != null && distance <= alertRadiusMeters;
  }

  /// Histéresis del bloqueo: una vez bloqueado, sigue bloqueado hasta que el
  /// bus se aleje más de `alertReArmMeters` (el movimiento del bus o el GPS
  /// cruzando el radio no debe hacer flapear el botón ni la guía). Se reinicia
  /// automáticamente al cambiar de bus.
  bool _applyBlockedHysteresis(
      String busId, bool liveBlocked, double? distance) {
    if (_latchedBusId != busId) {
      _latchedBusId = busId;
      _blockedLatched = liveBlocked;
    } else if (liveBlocked) {
      _blockedLatched = true;
    } else if (distance != null && distance > alertReArmMeters) {
      _blockedLatched = false;
    }
    return _blockedLatched;
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

  @override
  Widget build(BuildContext context) {
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

    return _sheetShell(
      toggleable: !tarjetaDeBus,
      child: tarjetaDeBus
          ? KeyedSubtree(
              key: ValueKey('sheet-bus-${selectedBuses.first}'),
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
    final routeTooFar =
        routeDistance != null && routeDistance > alertMaxRouteDistanceMeters;

    final String stateKey;
    final String title;
    final String subtitle;
    final IconData icon;
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
      subtitle = 'Para ver los buses, toca la barra de arriba y elige '
          'la empresa y su ruta';
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
    }

    return KeyedSubtree(
      key: ValueKey(stateKey),
      child: Padding(
        padding:
            const EdgeInsets.fromLTRB(AppSpacing.lg, 10, AppSpacing.lg, 40),
        // Título y frase son una sola cosa: "No hay buses en el mapa" y
        // el porqué. Sueltos, hay que deslizar dos veces para enterarse
        // de por qué la hoja está vacía.
        child: MergeSemantics(
          child: Column(
            children: [
              // El icono va en su medallón, como los de los tiles del
              // selector y el de la píldora de ubicación: suelto sobre la
              // arena era un glifo gris flotando en el hueco más grande de
              // la pantalla. No dice nada que no diga el título, así que en
              // voz alta no existe.
              ExcludeSemantics(
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(color: AppColors.hairline),
                  ),
                  child: Icon(icon, color: AppColors.textSecondary, size: 26),
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
                style: AppTextStyles.cuerpo
                    .copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
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

    // El bus ya está dentro del radio de aviso (≤1000 m): no se puede activar.
    final alreadyNear = !isActive && _busAlreadyNear(bus);
    final liveBlocked =
        ghostBlocked || alreadyNear || !locationState.hasPosition;
    // La ruta no pasa cerca: el aviso no sonaría nunca. Va FUERA de la
    // histéresis a propósito. La histéresis existe para que el bus moviéndose
    // alrededor del kilómetro no haga parpadear el botón; esto no se mueve
    // —depende del recorrido y del pin, no del bus— y meterlo dentro dejaría
    // el botón trabado en bloqueado después de mover el pin hasta la ruta.
    final routeTooFar = !isActive &&
        (route == null
            ? false
            : ref.watch(routeTooFarFromUserProvider(route.id)));
    final blocked =
        _applyBlockedHysteresis(busId, liveBlocked, distance) || routeTooFar;

    // Sin señal: excepción importante, se marca con coral.
    if (staleLabel != null) {
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
                const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, 20),
            child: _StickyAlertButton(
              key: widget.alertKey,
              onBlockedChanged: widget.onGuideAlertBlocked,
              isActive: isActive,
              blocked: isActive ? false : blocked,
              label: isActive
                  ? "Aviso activado"
                  : ghostBlocked
                      ? "Bus sin señal"
                      : "Avisarme cuando esté cerca",
              onPressed: () => _toggleAlert(busId),
            ),
          ),
        ],
      );
    }

    // Con el aviso activo, el detalle explica que se puede cambiar de app,
    // pero no deslizar Ya Viene fuera de recientes ni forzar su cierre.
    final stateDetail = isActive
        ? "Puedes cambiar de aplicación; no cierres Ya Viene del todo"
        : !locationState.hasPosition
            ? "Toca el mapa para indicar dónde estás"
            : routeTooFar
                ? "El recorrido de esta ruta no pasa cerca de tu punto: el "
                    "aviso no sonaría. Mueve tu punto o elige otra ruta"
                : distance == null
                    ? "Buscando la posición del bus…"
                    : null;

    // Estado → color de la franja y de la métrica grande (número o palabra).
    Color stripColor;
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
      stripColor = AppColors.textSecondary;
      metricText = "Sin tu ubicación";
      metricSpoken = metricText;
    } else if (distance == null) {
      stripColor = AppColors.textSecondary;
      metricText = "Calculando";
      metricSpoken = metricText;
    } else {
      // V1: el número hero carga la urgencia en su propio color, en vez de
      // quedarse siempre en el mismo azul — lejos, acercándose o ya casi.
      stripColor = _urgencyColor(distance);
      final parts = _metricParts(distance, referencia);
      metricText = parts.$1;
      metricUnit = parts.$2;
      metricSpoken = _metricSpoken(distance, referencia);
    }
    final isNumberMetric = metricUnit != null;

    return Padding(
      // La tarjeta del bus se muestra entera, siempre: es la única que no se
      // pliega, así que no tiene una versión corta que ajustar.
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 6, AppSpacing.lg, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Franja fina de estado: el color de la identidad en cada estado.
          // Cuando el bus se acerca y cambia de tramo, el color pasa de uno
          // a otro en vez de saltar.
          AnimatedContainer(
            duration: AppMotion.duracion(context, AppMotion.pausado),
            curve: AppMotion.curvaCambio,
            height: 4,
            decoration: BoxDecoration(
              color: stripColor,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
          ),
          const SizedBox(height: 18),
          // Identidad del bus: "Bus SQA223" (ver `busTitulo`). Encabeza la
          // tarjeta, así que va en `subtitulo` —negro y en negrita—, no en
          // la etiqueta gris de 13 que se perdía encima del número.
          Text(
            busTitulo,
            textAlign: TextAlign.center,
            style: AppTextStyles.subtitulo,
          ),
          const SizedBox(height: 10),
          // Métrica principal: número grande que respira, o el estado en
          // palabras. F10: override sobre AppTextStyles.etaNumber (mismo
          // TextStyle base) en vez de un literal duplicado.
          // El número y su unidad son dos bloques —64 y 15— y en voz alta
          // se leerían como "850" y luego "m de ti", con una pausa en
          // medio y la unidad abreviada. Aquí se dicen en una sola frase.
          Semantics(
            label: metricSpoken,
            excludeSemantics: true,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // El color del número acompaña al de la franja, al mismo
                // paso: los dos dicen lo mismo y cambian juntos.
                TweenAnimationBuilder<Color?>(
                  tween: ColorTween(end: stripColor),
                  duration: AppMotion.duracion(context, AppMotion.pausado),
                  curve: AppMotion.curvaCambio,
                  builder: (context, color, _) => Text(
                    metricText,
                    key: widget.metricKey,
                    textAlign: TextAlign.center,
                    // El número es `dato`, el rol que existe para él. Cuando
                    // en su sitio va una palabra —"Sin señal", "Llegando"—
                    // no cabe a 64 ni tendría sentido en w200: pasa a
                    // `display`, que es el otro rol grande, y ocupa el mismo
                    // hueco.
                    style: (isNumberMetric
                            ? AppTextStyles.dato
                            : AppTextStyles.display)
                        .copyWith(color: color),
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
          ),
          if (stateDetail != null) ...[
            const SizedBox(height: 14),
            Text(
              stateDetail,
              style: AppTextStyles.cuerpoFuerte
                  .copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
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
        ],
      ),
    );
  }

  /// La misma distancia, dicha entera y en castellano.
  ///
  /// En pantalla la unidad va abreviada porque debajo del número se lee
  /// sola; en voz alta "m" es una letra suelta y el punto decimal se
  /// pronuncia "punto". [referencia] dice desde dónde se mide: "de ti" o
  /// "de tu pin anterior".
  String _metricSpoken(double meters, String referencia) {
    if (meters < 1000) {
      final m = meters.round();
      return 'A $m ${m == 1 ? "metro" : "metros"} $referencia';
    }
    final km = (meters / 1000).toStringAsFixed(1).replaceAll('.', ',');
    return 'A $km kilómetros $referencia';
  }

  /// Divide la distancia en número grande + unidad: ("850", "m de ti") o
  /// ("1.4", "km de tu pin anterior").
  (String, String) _metricParts(double meters, String referencia) {
    if (meters < 1000) return (meters.round().toString(), "m $referencia");
    final km = (meters / 1000).toStringAsFixed(1);
    return (km, "km $referencia");
  }

  /// V1: verde lejos, ámbar acercándose, coral ya casi — el mismo semáforo
  /// que ya usa `alertRadiusMeters` para "el bus ya está cerca".
  ///
  /// Van las variantes accesibles del semáforo, no las de relleno: este
  /// color pinta el número de 64 en peso 200, que es el trazo más fino de
  /// toda la app y lo único que la app existe para decir. Los tres de
  /// relleno se quedaban en 2,9:1 sobre la arena, por debajo del 3:1 que
  /// pide la norma hasta para un icono; estos tres dan 5:1 y, entre
  /// ellos, el mismo 5:1, así que ninguna distancia se lee más pesada que
  /// otra por culpa del color.
  Color _urgencyColor(double meters) {
    if (meters < 300) return AppColors.coralAccessible;
    if (meters < alertRadiusMeters) return AppColors.warningAccessible;
    return AppColors.primaryAccessible;
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
          // V6: el rebote se reserva para el CTA principal de la app — el
          // resto de los botones se queda con la entrada enfatizada.
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
