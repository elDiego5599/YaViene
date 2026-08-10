import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import '../../../../core/services/bus_notification_service.dart';
import '../../../notifications/presentation/providers/proximity_alerts_provider.dart';
import '../providers/eta_provider.dart';
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
  static const double _expandedMapInset = 338;
  static const double _collapsedMapInset = 120;
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
      // El bus ya está dentro del radio de aviso: no se puede notificar su
      // llegada (llegó antes de activar el aviso).
      if (_busAlreadyNear(bus)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                'El bus $busId ya está dentro del radio de aviso ($alertRadiusMeters m); '
                'ya no se puede notificar su llegada.'),
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
      return const SizedBox.shrink();
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

    return GestureDetector(
      onVerticalDragEnd: (details) {
        if (details.primaryVelocity != null) {
          if (details.primaryVelocity! > 0 && _isExpanded) {
            _toggleSheet();
          } else if (details.primaryVelocity! < 0 && !_isExpanded) {
            _toggleSheet();
          }
        }
      },
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
                  onTap: _toggleSheet,
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
                if (_isExpanded)
                  if (selectedBuses.isEmpty)
                    _buildEmptyState()
                  else
                    _buildSingleBusState(
                        selectedBuses.first, busById[selectedBuses.first]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(24, 10, 24, 40),
          child: Column(
            children: [
              Icon(Icons.touch_app_rounded, color: Color(0xFF94A3B8), size: 32),
              SizedBox(height: 12),
              Text(
                "Toca un bus en el mapa",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
              ),
              SizedBox(height: 4),
              Text(
                "Selecciona un bus para darle seguimiento",
                style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
              ),
            ],
          ),
    );
  }

  Widget _buildSingleBusState(String busId, BusPosition? bus) {
    final isActive = ref.watch(activeAlertsProvider).contains(busId);
    final staleLabel = _staleLabel(bus);
    final alreadyNear = !isActive && _busAlreadyNear(bus);
    final ghostBlocked = !isActive && bus != null && bus.isGhostBus;

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
              blocked: alreadyNear || ghostBlocked,
              label: isActive
                  ? "AVISARÉ CUANDO $busId VUELVA A TRANSMITIR"
                  : ghostBlocked
                      ? "BUS $busId SIN SEÑAL"
                      : alreadyNear
                          ? "BUS $busId YA ESTÁ CERCA"
                          : "AVISARME CUANDO $busId ESTÉ CERCA",
              onPressed: () => _toggleAlert(busId),
            ),
          ),
        ],
      );
    }

    final eta = ref.watch(busEtaProvider(busId));
    final (bigValue, bigColor, detailLabel, showMinutesSub) =
        _etaDisplay(eta, busId);

    return Column(
      children: [
        const SizedBox(height: 4),
        Text(bigValue,
            style: TextStyle(
                fontSize: 84,
                fontWeight: FontWeight.w200,
                color: bigColor,
                height: 0.9,
                letterSpacing: -3.0)),
        const SizedBox(height: 6),
        if (showMinutesSub)
          Text(
            "minutos aprox. para que llegue ${_directionLabel(eta)} \u2022 Bus $busId",
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B)),
          ),
        if (!showMinutesSub)
          Text(detailLabel,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B))),
        const SizedBox(height: 10),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 28),
          child: Text(
            "Estimación en tiempo real según la velocidad del bus: el tráfico "
            "puede cambiar y el tiempo variar. Te recomendamos estar pendiente "
            "del mapa y del bus hasta que llegue.",
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 12,
                height: 1.4,
                fontWeight: FontWeight.w500,
                color: Color(0xFF94A3B8)),
          ),
        ),
        const SizedBox(height: 18),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          child: _StickyAlertButton(
            isActive: isActive,
            blocked: alreadyNear || ghostBlocked,
            label: isActive
                ? "AVISARÉ CUANDO $busId ESTÉ CERCA"
                : ghostBlocked
                    ? "BUS $busId SIN SEÑAL"
                    : alreadyNear
                        ? "BUS $busId YA ESTÁ CERCA"
                        : "AVISARME CUANDO $busId ESTÉ CERCA",
            onPressed: () => _toggleAlert(busId),
          ),
        ),
      ],
    );
  }

  /// "de ida" / "de venida" para el subtítulo (vacío si no se sabe).
  String _directionLabel(EtaEstimate? eta) {
    if (eta == null) return '';
    switch (eta.direction) {
      case EtaDirection.ida:
        return '· de ida';
      case EtaDirection.venida:
        return '· de venida';
      case EtaDirection.desconocido:
        return '';
    }
  }

  /// Traduce el ETA en lo que se muestra: número grande, color, texto.
  (String, Color, String, bool) _etaDisplay(
      EtaEstimate? eta, String busId) {
    if (eta == null) {
      return ("—", const Color(0xFF94A3B8),
          "Calculando llegada \u2022 Bus $busId", false);
    }
    switch (eta.state) {
      case EtaState.enRuta:
        final minutes = eta.minutes ?? 0;
        return ("$minutes", const Color(0xFF14274E), "", true);
      case EtaState.trancado:
        final minutes = eta.minutes ?? 0;
        return ("$minutes", const Color(0xFFD97706),
            "min aprox. en tráncón: el bus avanza muy lento \u2022 Bus $busId",
            false);
      case EtaState.detenido:
        return ("—", const Color(0xFFD97706),
            "El bus está detenido (tráfico) \u2022 Bus $busId", false);
      case EtaState.yaPaso:
        return ("—", const Color(0xFFD97706),
            "El bus ya pasó por aquí: espera la próxima vuelta \u2022 Bus $busId",
            false);
    }
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
