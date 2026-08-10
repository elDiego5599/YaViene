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
  const EtaBottomSheet({super.key});

  @override
  ConsumerState<EtaBottomSheet> createState() => _EtaBottomSheetState();
}

class _EtaBottomSheetState extends ConsumerState<EtaBottomSheet> {
  static const double _expandedMapInset = 250;
  static const double _collapsedMapInset = 120;

  /// Distancia (m) a la que el bus se considera "pasando por la parada".
  static const double _passingRadiusMeters = 500;
  bool _isExpanded = true;
  double _lastPublishedInset = -1;
  Timer? _refreshTimer;

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
    if (!ref.read(activeAlertsProvider).contains(busId)) {
      // Sin posición (GPS negado y sin pin) el aviso nunca podría medir ni
      // dispararse: mejor explicarlo antes de armar una alerta muerta.
      final location = ref.read(userLocationProvider);
      if (!location.hasPosition) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'El aviso necesita saber dónde estás: toca el mapa en tu '
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
            content: Text(
                'El bus $busId ya está a menos de $alertRadiusMeters m; '
                'no se puede activar el aviso'),
          ));
        }
        return;
      }
      if (!await BusNotificationService.requestPermission()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Activa las notificaciones para recibir el aviso del bus'),
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
    notifier.toggleAlert(busId);
  }

  BusPosition? _busById(String busId) {
    final route = ref.read(selectedRouteProvider);
    if (route == null) return null;
    final positions =
        ref.read(busPositionsSourceProvider(route.id)).value;
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

    // Cambio de ruta (o borrarla): la selección y los avisos pertenecen a la
    // ruta anterior; se limpian para volver al estado "Toca un bus en el mapa".
    ref.listen<RouteInfo?>(selectedRouteProvider, (previous, next) {
      if (previous?.id == next?.id) return;
      ref.read(selectedBusesProvider.notifier).clear();
      ref.read(activeAlertsProvider.notifier).clear();
    });

    if (selectedRoute == null) {
      _publishMapInset(0);
      // Sin ruta también se muestra la hoja: si aún no hay ubicación invita
      // a tocar el mapa desde el primer momento.
      return _sheetShell(toggleable: false, child: _buildEmptyState());
    }

    _publishMapInset();

    final busesAsync = ref.watch(busPositionsSourceProvider(selectedRoute.id));
    final buses = busesAsync.value ?? const <BusPosition>[];
    final busById = {for (final b in buses) b.busId: b};

    // Bus seleccionado que ya no está en la ruta (left/hidden/removed):
    // se quita de la selección y de los avisos. Solo cuando la ruta ya
    // cargó (value != null): mientras está cargando no se toca nada.
    ref.listen<AsyncValue<List<BusPosition>>>(
        busPositionsSourceProvider(selectedRoute.id), (prev, next) {
      final loaded = next.value;
      if (loaded == null) return;
      final ids = {for (final b in loaded) b.busId};
      final selNotifier = ref.read(selectedBusesProvider.notifier);
      final alertNotifier = ref.read(activeAlertsProvider.notifier);
      for (final id in ref.read(selectedBusesProvider).toList()) {
        if (ids.contains(id)) continue;
        if (ref.read(selectedBusesProvider).contains(id)) selNotifier.toggleBus(id);
        if (ref.read(activeAlertsProvider).contains(id)) alertNotifier.toggleAlert(id);
      }
    });

    return _sheetShell(
      toggleable: true,
      child: _isExpanded
          ? selectedBuses.isEmpty
              ? _buildEmptyState()
              : _buildSingleBusState(
                  selectedBuses.first, busById[selectedBuses.first])
          : const SizedBox.shrink(),
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
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
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
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final hasPosition =
        ref.watch(userLocationProvider.select((s) => s.hasPosition));
    final (title, subtitle) = hasPosition
        ? ("Toca un bus en el mapa", "Selecciona un bus para darle seguimiento")
        : ("Toca el mapa para indicar dónde estás",
            "Selecciona tu ubicación y mira los buses cerca de ti");
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 40),
      child: Column(
        children: [
          const Icon(Icons.touch_app_rounded,
              color: Color(0xFF94A3B8), size: 32),
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
    );
  }

  Widget _buildSingleBusState(String busId, BusPosition? bus) {
    final isActive = ref.watch(activeAlertsProvider).contains(busId);
    final staleLabel = _staleLabel(bus);
    final ghostBlocked = !isActive && bus != null && bus.isGhostBus;
    final distance = _distanceToBus(bus);

    // Defensa: el bus seleccionado ya no está en la ruta (aún no se procesó
    // la limpieza) → volvemos al estado "toca un bus", no a un bus fantasma.
    if (bus == null) return _buildEmptyState();

    if (staleLabel != null) {
      return Column(
        children: [
          const SizedBox(height: 10),
          const Icon(Icons.wifi_off_rounded, color: Color(0xFF94A3B8), size: 56),
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
              isActive: isActive,
              blocked: ghostBlocked,
              label: isActive
                  ? "AVISARÉ CUANDO VUELVA A TRANSMITIR"
                  : ghostBlocked
                      ? "BUS SIN SEÑAL"
                      : "AVISARME CUANDO ESTÉ CERCA",
              onPressed: () => _toggleAlert(busId),
            ),
          ),
        ],
      );
    }

    // El bus está cruzando la parada (≤500 m): no hace falta aviso.
    final alreadyNear = !isActive && _busAlreadyNear(bus);
    final passing = distance != null && distance <= _passingRadiusMeters;
    // Con el aviso activo, el detalle recuerda mantener la app abierta en
    // segundo plano; si no, solo los estados especiales detallan.
    final stateDetail = isActive
        ? "No cierres la aplicación para que la notificación te llegue"
        : passing
            ? null
            : distance == null
                ? "Buscando la posición del bus…"
                : null;
    final (stateTitle, stateColor) = passing
        ? ("VA PASANDO", const Color(0xFFD97706))
        : distance == null
            ? ("CALCULANDO", const Color(0xFF94A3B8))
            : (_formatDistance(distance), const Color(0xFF14274E));

    return Column(
      children: [
        const SizedBox(height: 8),
        Text("Bus $busId",
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF475569),
                letterSpacing: -0.3)),
        const SizedBox(height: 6),
        Text(stateTitle,
            style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: stateColor,
                height: 1.05,
                letterSpacing: -1.0)),
        if (stateDetail != null) ...[
          const SizedBox(height: 8),
          Text(stateDetail,
              style: const TextStyle(
                  fontSize: 14,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B)),
              textAlign: TextAlign.center),
        ],
        const SizedBox(height: 18),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          child: _StickyAlertButton(
            isActive: isActive,
            blocked: ghostBlocked || alreadyNear || passing,
            label: isActive
                ? "AVISARÉ CUANDO ESTÉ CERCA"
                : ghostBlocked
                    ? "BUS SIN SEÑAL"
                    : passing
                        ? "BUS VA PASANDO"
                        : alreadyNear
                            ? "BUS YA ESTÁ CERCA"
                            : "AVISARME CUANDO ESTÉ CERCA",
            onPressed: () => _toggleAlert(busId),
          ),
        ),
      ],
    );
  }

  /// "A 850 m de ti" / "A 1.4 km de ti".
  String _formatDistance(double meters) {
    if (meters < 1000) return "A ${meters.round()} m de ti";
    return "A ${(meters / 1000).toStringAsFixed(1)} km de ti";
  }
}

class _StickyAlertButton extends StatefulWidget {
  final bool isActive;

  /// Bus ya dentro del radio de aviso: el botón se pinta gris (bloqueado).
  final bool blocked;
  final String label;
  final VoidCallback onPressed;

  const _StickyAlertButton({
    required this.isActive,
    this.blocked = false,
    required this.label,
    required this.onPressed,
  });

  @override
  State<_StickyAlertButton> createState() => _StickyAlertButtonState();
}

class _StickyAlertButtonState extends State<_StickyAlertButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = widget.blocked
        ? const Color(0xFF94A3B8)
        : widget.isActive
            ? const Color(0xFF065F46)
            : const Color(0xFF00A859);

    return GestureDetector(
      onTap: () {
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
                Text(
                  widget.label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.5,
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
