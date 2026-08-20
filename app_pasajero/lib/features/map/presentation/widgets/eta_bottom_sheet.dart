import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import '../../../../core/services/bus_notification_service.dart';
import '../../../notifications/presentation/providers/proximity_alerts_provider.dart';
import '../providers/map_view_state.dart';
import '../providers/tracking_providers.dart';
import '../providers/user_location_provider.dart';
import '../utils/geo.dart';

class EtaBottomSheet extends ConsumerStatefulWidget {
  const EtaBottomSheet({
    super.key,
    this.alertKey,
    this.metricKey,
    this.detailKey,
    this.onGuideAlertBlocked,
  });

  /// GlobalKey sobre el botón de aviso: el tour de primer uso lo mide para
  /// abrir su hueco sobre él cuando el usuario toca su primer bus.
  final GlobalKey? alertKey;
  final GlobalKey? metricKey;
  final GlobalKey? detailKey;
  final ValueChanged<bool>? onGuideAlertBlocked;

  @override
  ConsumerState<EtaBottomSheet> createState() => _EtaBottomSheetState();
}

class _EtaBottomSheetState extends ConsumerState<EtaBottomSheet> {
  static const double _expandedMapInset = 250;
  static const double _collapsedMapInset = 120;

  bool _isExpanded = true;
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

  void _toggleSheet() {
    setState(() => _isExpanded = !_isExpanded);
    _publishMapInset();
  }

  /// Activa/desactiva la alerta de un bus. Al activar, pide el permiso de
  /// notificaciones en contexto; sin permiso no tiene sentido avisar.
  Future<void> _toggleAlert(String busId) async {
    final notifier = ref.read(activeAlertsProvider.notifier);
    final wasActive = ref.read(activeAlertsProvider).contains(busId);
    if (!wasActive) {
      // Sin posición (GPS negado y sin pin) el aviso nunca podría medir ni
      // dispararse: mejor explicarlo antes de armar una alerta muerta.
      final location = ref.read(userLocationProvider);
      if (!location.hasPosition) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:
                Text('El aviso necesita saber dónde estás: toca el mapa en tu '
                    'ubicación o activa el GPS primero'),
          ));
        }
        return;
      }
      final bus = _busById(busId);
      // Bus sin señal: su posición es la última conocida; no se puede
      // prometer un aviso de llegada mientras no transmita.
      if (bus != null && bus.isGhostBus) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                'El bus $busId está sin señal; el aviso se activa cuando vuelva a transmitir'),
          ));
        }
        return;
      }
      // El usuario puede pedir el aviso de cualquier bus; el aviso dispara
      // cuando el bus entra al radio.
      // El bus ya está dentro del radio de aviso: no se puede notificar su
      // llegada (llegó antes de activar el aviso).
      if (_busAlreadyNear(bus)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text('El bus $busId ya está a menos de $alertRadiusMeters m; '
                    'no se puede activar el aviso'),
          ));
        }
        return;
      }
      // Comprobación temprana para dar feedback antes de pedir permiso.
      if (ref.read(activeAlertsProvider).length >= 2) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Ya tienes 2 avisos activos: desactiva uno o espera a que '
                'termine para activar otro. Recuerda no cerrar la aplicación'),
          ));
        }
        return;
      }
      if (!await BusNotificationService.requestPermission()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:
                Text('Activa las notificaciones para recibir el aviso del bus'),
            action: SnackBarAction(
              label: 'Ajustes',
              onPressed: openAppSettings,
            ),
          ));
        }
        return;
      }
    }
    HapticFeedback.mediumImpact();
    final routeId = ref.read(selectedRouteProvider)?.id;
    if (wasActive) {
      notifier.deactivateAlert(busId);
      ref.read(proximityAlertsProvider.notifier).disarmAlert(busId);
      return;
    }
    // La validación anterior ocurre antes del await del permiso. Esta segunda
    // comprobación atómica evita que dos taps concurrentes armen un tercer
    // aviso mientras la solicitud de permiso está en vuelo.
    if (!notifier.activateAlert(busId)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Ya tienes 2 avisos activos: desactiva uno o espera a que '
              'termine para activar otro. Recuerda no cerrar la aplicación'),
        ));
      }
      return;
    }
    if (routeId != null) {
      // Quedó armado: se registra la ruta para que el aviso mida aunque se
      // cambie de ruta en pantalla.
      ref.read(proximityAlertsProvider.notifier).armAlert(busId, routeId);
    } else {
      // Defensa contra un estado imposible: nunca dejes un aviso activo sin
      // ruta ni suscripción de posiciones.
      notifier.deactivateAlert(busId);
    }
  }

  BusPosition? _busById(String busId) {
    final route = ref.read(selectedRouteProvider);
    if (route == null) return null;
    final positions = ref.read(busPositionsSourceProvider(route.id)).value;
    if (positions == null) return null;
    for (final p in positions) {
      if (p.busId == busId) return p;
    }
    return null;
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
    final inset =
        forcedInset ?? (_isExpanded ? _expandedMapInset : _collapsedMapInset);
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
          !_isExpanded) {
        setState(() => _isExpanded = true);
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

    return _sheetShell(
      toggleable: true,
      child: !_isExpanded
          ? const KeyedSubtree(
              key: ValueKey('sheet-collapsed'),
              child: SizedBox.shrink(),
            )
          : selectedBuses.isEmpty
              ? _buildEmptyState(buses)
              : KeyedSubtree(
                  key: const ValueKey('sheet-bus'),
                  child: _buildSingleBusState(
                    selectedBuses.first,
                    busById[selectedBuses.first],
                    buses,
                  ),
                ),
    );
  }

  /// Carcasa de la hoja: asa de arrastre + contenedor blanco redondeado.
  /// [toggleable] controla el colapso por arrastre/toque del asa (sin ruta
  /// seleccionada la hoja no colapsa: siempre muestra su contenido).
  Widget _sheetShell({required Widget child, required bool toggleable}) {
    return GestureDetector(
      onVerticalDragEnd: toggleable
          ? (details) {
              if (details.primaryVelocity != null) {
                if (details.primaryVelocity! > 0 && _isExpanded) {
                  _toggleSheet();
                } else if (details.primaryVelocity! < 0 && !_isExpanded) {
                  _toggleSheet();
                }
              }
            }
          : null,
      child: AnimatedSize(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        alignment: Alignment.bottomCenter,
        child: Container(
          key: widget.detailKey,
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.arena,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF14274E).withValues(alpha: 0.08),
                blurRadius: 32,
                offset: const Offset(0, -8),
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
                        color: const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
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
            Icon(icon, color: const Color(0xFF94A3B8), size: 32),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
              textAlign: TextAlign.center,
            ),
          ],
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

    // Defensa: el bus seleccionado ya no está en la ruta (aún no se procesó
    // la limpieza) → volvemos al estado "toca un bus", no a un bus fantasma.
    if (bus == null) return _buildEmptyState(buses);

    // El bus ya está dentro del radio de aviso (≤1000 m): no se puede activar.
    final alreadyNear = !isActive && _busAlreadyNear(bus);
    final liveBlocked =
        ghostBlocked || alreadyNear || !locationState.hasPosition;
    final blocked = _applyBlockedHysteresis(busId, liveBlocked, distance);

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
          Text("Bus $busId · conserva su última posición",
              style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF94A3B8))),
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
            : distance == null
                ? "Buscando la posición del bus…"
                : null;

    // Estado → color de la franja y de la métrica grande (número o palabra).
    Color stripColor;
    String metricText = '';
    String? metricUnit;
    if (!locationState.hasPosition) {
      stripColor = const Color(0xFF94A3B8);
      metricText = "Sin tu ubicación";
    } else if (distance == null) {
      stripColor = const Color(0xFF94A3B8);
      metricText = "Calculando";
    } else {
      stripColor = isActive ? AppColors.primary : AppColors.electricBlue;
      final parts = _metricParts(distance);
      metricText = parts.$1;
      metricUnit = parts.$2;
    }
    final isNumberMetric = metricUnit != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 6, 24, 20),
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
          // Identidad de ruta: bus + línea, en tipo editorial pequeño.
          Text(
            "Bus $busId · ${route?.name ?? ''}",
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF64748B),
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 10),
          // Métrica principal: número grande que respira, o el estado en palabras.
          Text(
            metricText,
            key: widget.metricKey,
            textAlign: TextAlign.center,
            style: isNumberMetric
                ? TextStyle(
                    fontSize: 64,
                    fontWeight: FontWeight.w200,
                    color: stripColor,
                    height: 1.0,
                    letterSpacing: -2.0,
                  )
                : TextStyle(
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
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
            ),
          ],
          if (stateDetail != null) ...[
            const SizedBox(height: 14),
            Text(
              stateDetail,
              style: const TextStyle(
                  fontSize: 14,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B)),
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
        ? const Color(0xFF94A3B8)
        : widget.isActive
            ? const Color(0xFF065F46)
            : const Color(0xFF00A859);

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
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
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
            duration: const Duration(milliseconds: 200),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
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
