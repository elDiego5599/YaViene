import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import '../../../../core/utils/bus_labels.dart';
import '../../../notifications/presentation/providers/proximity_alerts_provider.dart';
import '../providers/alert_toggle_provider.dart';
import '../providers/map_view_state.dart';
import '../providers/route_reach_provider.dart';
import '../providers/tracking_providers.dart';
import '../providers/user_location_provider.dart';
import '../providers/visible_buses_provider.dart';
import '../utils/geo.dart';
import 'alert_guards.dart' show kmLabel;

class EtaBottomSheet extends ConsumerStatefulWidget {
  const EtaBottomSheet({
    super.key,
    this.alertKey,
    this.metricKey,
    this.metricUnitKey,
    this.detailKey,
    this.onGuideAlertBlocked,
  });

  /// GlobalKey sobre el botón de aviso: el tour de primer uso lo mide para
  /// abrir su hueco sobre él cuando el usuario toca su primer bus.
  final GlobalKey? alertKey;
  final GlobalKey? metricKey;
  final GlobalKey? metricUnitKey;
  final GlobalKey? detailKey;
  final ValueChanged<bool>? onGuideAlertBlocked;

  @override
  ConsumerState<EtaBottomSheet> createState() => _EtaBottomSheetState();
}

/// V3: 3 alturas de anclaje en vez de "abierta o cerrada" — como Uber. Un
/// arrastre mueve un escalón (colapsada↔peek↔expandida); tocar el asa salta
/// directo entre los dos extremos.
enum _SheetSnap { collapsed, peek, expanded }

class _EtaBottomSheetState extends ConsumerState<EtaBottomSheet> {
  static const double _expandedMapInset = 250;
  static const double _peekMapInset = 170;
  static const double _collapsedMapInset = 120;

  _SheetSnap _snap = _SheetSnap.expanded;
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
    // Refresca el texto "Sin señal · hace X min" de un bus fantasma: sin
    // posiciones nuevas la UI no se reconstruye sola.
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  /// Toca el asa: salta directo entre los dos extremos (sin pasar por peek),
  /// el mismo gesto rápido de "abrir/cerrar" de siempre.
  void _toggleSheet() {
    setState(() => _snap = _snap == _SheetSnap.collapsed
        ? _SheetSnap.expanded
        : _SheetSnap.collapsed);
    _publishMapInset();
  }

  /// Arrastra la hoja: un escalón hacia arriba o hacia abajo entre las 3
  /// alturas, en vez de saltar directo al extremo opuesto.
  void _stepSnap(int direction) {
    const order = _SheetSnap.values;
    final next = (_snap.index + direction).clamp(0, order.length - 1);
    if (next == _snap.index) return;
    setState(() => _snap = order[next]);
    _publishMapInset();
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

  /// Distancia en metros del usuario al bus; null si no se puede medir.
  double? _distanceToBus(BusPosition? bus) {
    if (bus == null) return null;
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
    final defaultInset = switch (_snap) {
      _SheetSnap.expanded => _expandedMapInset,
      _SheetSnap.peek => _peekMapInset,
      _SheetSnap.collapsed => _collapsedMapInset,
    };
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

    // Tocar un bus con la hoja colapsada debe mostrar la tarjeta del bus:
    // la selección nueva expande la hoja automáticamente.
    ref.listen<Set<String>>(selectedBusesProvider, (previous, next) {
      if (previous != null &&
          previous.isEmpty &&
          next.isNotEmpty &&
          _snap == _SheetSnap.collapsed) {
        setState(() => _snap = _SheetSnap.expanded);
      }
    });

    if (selectedRoute == null) {
      _publishMapInset(0);
      // Sin ruta tampoco se muestra la hoja: si aún no hay ubicación invita
      // a tocar el mapa desde el primer momento.
      return _sheetShell(
        toggleable: false,
        child: _buildEmptyState(const []),
      );
    }

    _publishMapInset();

    // La hoja habla de los buses que el usuario está viendo: la misma lista
    // recortada al radio que pinta el mapa. Los avisos siguen midiendo contra
    // la ruta entera; eso vive en proximity_alerts_provider.
    final busesAsync = ref.watch(visibleBusesProvider(selectedRoute.id));
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
    // El bus seleccionado nunca sale de la lista recortada (va en
    // `alwaysVisible`), así que alejarse del radio no lo deselecciona: solo
    // desaparecer de la ruta lo hace, que es lo que este listener busca.
    ref.listen<AsyncValue<List<BusPosition>>>(
        visibleBusesProvider(selectedRoute.id), (prev, next) {
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

    return _sheetShell(
      toggleable: true,
      child: _snap == _SheetSnap.collapsed
          ? const KeyedSubtree(
              key: ValueKey('sheet-collapsed'),
              child: SizedBox.shrink(),
            )
          : selectedBuses.isEmpty
              ? _buildEmptyState(buses)
              : KeyedSubtree(
                  key: ValueKey('sheet-bus-${_snap.name}'),
                  child: _buildSingleBusState(
                    selectedBuses.first,
                    busById[selectedBuses.first],
                    buses,
                    peek: _snap == _SheetSnap.peek,
                  ),
                ),
    );
  }

  /// Carcasa de la hoja: asa de arrastre + contenedor blanco redondeado.
  /// [toggleable] controla el colapso por arrastre/toque del asa (sin ruta
  /// seleccionada la hoja no colapsa: siempre muestra su contenido).
  Widget _sheetShell({required Widget child, required bool toggleable}) {
    return GestureDetector(
      // V3: el arrastre avanza un escalón entre las 3 alturas (Uber), no
      // salta directo al extremo opuesto.
      onVerticalDragEnd: toggleable
          ? (details) {
              final velocity = details.primaryVelocity;
              if (velocity == null) return;
              if (velocity > 0) {
                _stepSnap(-1);
              } else if (velocity < 0) {
                _stepSnap(1);
              }
            }
          : null,
      child: AnimatedSize(
        duration: AppMotion.pausado,
        curve: AppMotion.curvaEntrada,
        alignment: Alignment.bottomCenter,
        child: Container(
          key: widget.detailKey,
          width: double.infinity,
          // Un filo de un pixel separa la hoja del mapa mejor que una
          // sombra ancha: la sombra sobre un mapa lleno de color se lee
          // como suciedad, el filo se lee como borde.
          decoration: BoxDecoration(
            color: AppColors.arena,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border.all(color: AppColors.hairline),
            boxShadow: [
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
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: toggleable ? _toggleSheet : null,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 14, bottom: 18),
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: AppColors.divider,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                ),
                AnimatedSwitcher(
                  duration: AppMotion.normal,
                  switchInCurve: AppMotion.curvaEntrada,
                  switchOutCurve: AppMotion.curvaSalida,
                  transitionBuilder: (child, animation) =>
                      FadeTransition(opacity: animation, child: child),
                  child: child,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(List<BusPosition> buses) {
    final hasPosition =
        ref.watch(userLocationProvider.select((s) => s.hasPosition));
    final route = ref.watch(selectedRouteProvider);

    // Buses de la ruta que quedaron fuera del radio: sin esto, un mapa vacío
    // se lee como "esta ruta no tiene servicio", que casi nunca es lo que
    // pasa. Con esto se lee como "hay buses, pero no por aquí".
    final outOfRange =
        route == null ? 0 : ref.watch(busesOutOfRangeCountProvider(route.id));
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
      subtitle =
          'Pon tu punto de espera; después podrás mover el pin si hace falta';
      icon = Icons.touch_app_rounded;
    } else if (route == null) {
      stateKey = 'empty-no-route';
      title = 'Escoge empresa y ruta';
      subtitle = 'Para ver los buses, toca la barra de arriba y elige '
          'la empresa y su ruta';
      icon = Icons.route_rounded;
    } else if (buses.isEmpty && routeTooFar) {
      // El caso más confuso de todos: el mapa está vacío no porque no haya
      // buses, sino porque la ruta entera pasa lejos. Decirlo evita que el
      // usuario espere sentado un bus que no viene por aquí.
      stateKey = 'empty-route-far';
      title = 'Esta ruta no pasa cerca de ti';
      subtitle = 'Lo más que se acerca su recorrido son '
          '${kmLabel(routeDistance)} de tu punto. '
          'Mueve tu punto de espera o elige otra ruta';
      icon = Icons.wrong_location_rounded;
    } else if (buses.isEmpty && outOfRange > 0) {
      stateKey = 'empty-buses-far';
      title = 'Ningún bus cerca de ti';
      subtitle = outOfRange == 1
          ? 'Hay 1 bus en esta ruta, pero va a más de '
              '${visibleRadiusMeters ~/ 1000} km de tu punto. Aparecerá al '
              'acercarse'
          : 'Hay $outOfRange buses en esta ruta, pero todos van a más de '
              '${visibleRadiusMeters ~/ 1000} km de tu punto. Aparecerán al '
              'acercarse';
      icon = Icons.travel_explore_rounded;
    } else if (buses.isEmpty) {
      stateKey = 'empty-no-buses';
      title = 'No hay buses en el mapa';
      subtitle =
          'Cuando un bus de esta ruta transmita posición, aparecerá aquí';
      icon = Icons.directions_bus_rounded;
    } else {
      stateKey = 'empty-pick-bus';
      title = 'Toca un bus en el mapa';
      subtitle = 'Selecciona un bus para darle seguimiento';
      icon = Icons.touch_app_rounded;
    }

    return KeyedSubtree(
      key: ValueKey(stateKey),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 10, 24, 40),
        child: Column(
          children: [
            Icon(icon, color: AppColors.textDisabled, size: 32),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style:
                  const TextStyle(fontSize: 14, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSingleBusState(
      String busId, BusPosition? bus, List<BusPosition> buses,
      {bool peek = false}) {
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
          const Icon(Icons.wifi_off_rounded, color: AppColors.coral, size: 56),
          const SizedBox(height: 10),
          Text(staleLabel,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF475569),
                  letterSpacing: -0.4)),
          const SizedBox(height: 4),
          Text("$busLabel · conserva su última posición",
              style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDisabled)),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
            child: _StickyAlertButton(
              key: widget.alertKey,
              onBlockedChanged: widget.onGuideAlertBlocked,
              isActive: isActive,
              blocked: isActive ? false : blocked,
              label: isActive
                  ? "AVISO ACTIVADO"
                  : ghostBlocked
                      ? "BUS SIN SEÑAL"
                      : "AVISARME CUANDO ESTÉ CERCA",
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
    if (!locationState.hasPosition) {
      stripColor = AppColors.textDisabled;
      metricText = "Sin tu ubicación";
    } else if (distance == null) {
      stripColor = AppColors.textDisabled;
      metricText = "Calculando";
    } else {
      // V1: el número hero carga la urgencia en su propio color, en vez de
      // quedarse siempre en el mismo azul — lejos, acercándose o ya casi.
      stripColor = _urgencyColor(distance);
      final parts = _metricParts(distance);
      metricText = parts.$1;
      metricUnit = parts.$2;
    }
    final isNumberMetric = metricUnit != null;

    return Padding(
      // V3: en peek la hoja muestra solo el número y el botón — menos
      // relleno vertical porque ya no lleva identidad ni detalle.
      padding: EdgeInsets.fromLTRB(24, peek ? 2 : 6, 24, peek ? 14 : 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Franja fina de estado: el color de la identidad en cada estado.
          Container(
            height: 4,
            decoration: BoxDecoration(
              color: stripColor,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(height: 18),
          if (!peek) ...[
            // Identidad de ruta: misma "ruta - placa" que ya usa
            // Notificaciones.
            Text(
              busLabel,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 10),
          ],
          // Métrica principal: número grande que respira, o el estado en
          // palabras. F10: override sobre AppTextStyles.etaNumber (mismo
          // TextStyle base) en vez de un literal duplicado.
          Text(
            metricText,
            key: widget.metricKey,
            textAlign: TextAlign.center,
            style: isNumberMetric
                ? AppTextStyles.etaNumber.copyWith(
                    fontSize: 64,
                    color: stripColor,
                    height: 1.0,
                    letterSpacing: -2.0,
                  )
                : AppTextStyles.etaNumber.copyWith(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: stripColor,
                    height: 1.1,
                    letterSpacing: -1.0,
                  ),
          ),
          if (metricUnit != null) ...[
            const SizedBox(height: 6),
            Text(
              metricUnit,
              key: widget.metricUnitKey,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ],
          if (!peek && stateDetail != null) ...[
            const SizedBox(height: 14),
            Text(
              stateDetail,
              style: const TextStyle(
                  fontSize: 14,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary),
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
                ? "AVISO ACTIVADO"
                : ghostBlocked
                    ? "BUS SIN SEÑAL"
                    : routeTooFar
                        ? "ESTA RUTA NO PASA CERCA"
                        : blocked
                            ? "BUS YA ESTÁ CERCA"
                            : "AVISARME CUANDO ESTÉ CERCA",
            onPressed: () => _toggleAlert(busId),
          ),
        ],
      ),
    );
  }

  /// Divide la distancia en número grande + unidad: ("850", "m de ti") o
  /// ("1.4", "km de ti").
  (String, String) _metricParts(double meters) {
    if (meters < 1000) return (meters.round().toString(), "m de ti");
    final km = (meters / 1000).toStringAsFixed(1);
    return (km, "km de ti");
  }

  /// V1: verde lejos, ámbar acercándose, coral ya casi — el mismo semáforo
  /// que ya usa `alertRadiusMeters` para "el bus ya está cerca".
  Color _urgencyColor(double meters) {
    if (meters < 300) return AppColors.coral;
    if (meters < alertRadiusMeters) return AppColors.warning;
    return AppColors.primary;
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

  @override
  Widget build(BuildContext context) {
    final backgroundColor = widget.blocked
        ? AppColors.textDisabled
        : widget.isActive
            ? const Color(0xFF065F46)
            : AppColors.primary;

    return GestureDetector(
      onTap: () {
        // Un botón bloqueado (por histéresis) no debe poder armar el aviso
        // aunque el bus ya no esté dentro del radio: el estado visual y la
        // guía dependen de ese bloqueo.
        if (widget.blocked) return;
        HapticFeedback.mediumImpact();
        widget.onPressed();
      },
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapCancel: () => setState(() => _isPressed = false),
      onTapUp: (_) => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.96 : 1,
        duration: AppMotion.instante,
        // V6: el rebote se reserva para el CTA principal de la app — el
        // resto de los botones se queda con easeOutCubic.
        curve: Curves.easeOutBack,
        child: AnimatedContainer(
          duration: AppMotion.normal,
          curve: AppMotion.curvaEntrada,
          width: double.infinity,
          height: 60,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(999),
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
                Icon(
                  widget.blocked
                      ? Icons.notifications_off_rounded
                      : widget.isActive
                          ? Icons.check_circle_rounded
                          : Icons.notifications_active_rounded,
                  color: Colors.white,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
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
