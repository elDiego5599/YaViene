import 'package:flutter/gestures.dart' show PointerScrollEvent;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/clock_widget.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/fleet_bus.dart';
import '../providers/fleet_providers.dart';
import '../widgets/bus_dialog.dart';
import '../widgets/control_map.dart';
import '../widgets/fleet_list_tile.dart';
import '../widgets/route_dialog.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  bool _refreshing = false;
  ProviderSubscription<bool>? _sessionExpiredSub;

  @override
  void initState() {
    super.initState();
    _sessionExpiredSub = ref.listenManual(
      fleetProvider.select((s) => s.sessionExpired),
      (previous, expired) {
        if (!expired || !mounted) return;
        ref.read(fleetProvider.notifier).acknowledgeSessionExpired();
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Tu sesión expiró'),
            content: const Text(
              'La sesión del administrador venció o fue revocada. '
              'Vuelve a iniciar sesión para continuar.',
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  Navigator.of(dialogContext).pop();
                  await _logout();
                },
                child: const Text('Iniciar sesión'),
              ),
            ],
          ),
        );
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(fleetProvider.notifier).start();
    });
  }

  @override
  void dispose() {
    _sessionExpiredSub?.close();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    final started = DateTime.now();
    try {
      await ref.read(fleetProvider.notifier).refresh();
    } finally {
      final rest = const Duration(milliseconds: 700) - DateTime.now().difference(started);
      if (rest > Duration.zero) {
        await Future<void>.delayed(rest);
      }
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _logout() async {
    // Apaga el socket de flota y resetea el estado antes de salir: no queda
    // una conexión viva con la sesión ya cerrada.
    ref.read(fleetProvider.notifier).stop();
    await ref.read(authProvider.notifier).logout();
    if (mounted) context.go('/login');
  }

  void _showBusDialog({FleetBus? bus}) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => BusDialog(
        bus: bus,
        onDelete: bus == null
            ? null
            : () async {
                final messenger = ScaffoldMessenger.of(context);
                try {
                  await ref.read(fleetProvider.notifier).removeBus(bus.busId);
                } catch (_) {
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('No se pudo eliminar el bus.'),
                      backgroundColor: AppColors.danger,
                    ),
                  );
                }
              },
      ),
    );
  }

  void _showRouteDialog() {
    showDialog<void>(
      context: context,
      builder: (_) => const RouteDialog(),
    );
  }

  Future<void> _confirmDeleteSelected(FleetBus bus) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
        title: Text(
          'Eliminar bus',
          style: AppType.ui(
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Text(
          '¿Eliminar ${bus.placa.isEmpty ? bus.busId : bus.placa} de la flota? '
          'Los pasajeros dejarán de verlo de inmediato. Esta acción no se puede '
          'deshacer.',
          style: AppType.ui(fontSize: 13.5, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              textStyle: AppType.ui(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
            child: const Text('ELIMINAR'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await ref.read(fleetProvider.notifier).removeBus(bus.busId);
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No se pudo eliminar el bus.'),
              backgroundColor: AppColors.danger,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final fleet = ref.watch(fleetProvider);

    final buses = fleet.buscar(_query);

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(
            connection: fleet.connection,
            onLogout: _logout,
          ),
          _TopBar(
            refreshing: _refreshing,
            searchController: _searchController,
            onSearchChanged: (v) => setState(() => _query = v),
            onRefresh: _refresh,
            onToggleAllVisibility: () {
              final visible = !fleet.buses.values.every((b) => b.visible);
              ref.read(fleetProvider.notifier).setAllVisibility(visible);
            },
            allBusesVisible: fleet.buses.isNotEmpty &&
                fleet.buses.values.every((b) => b.visible),
          ),
          if (fleet.error != null) _ErrorBanner(message: fleet.error!),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: _RouteFilters(
              fleet: fleet,
              onSelect: (routeId) =>
                  ref.read(fleetProvider.notifier).setRouteFilter(routeId),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 1,
                    child: _FleetPanel(
                      buses: buses,
                      fleet: fleet,
                      onAddBus: () => _showBusDialog(),
                      onAddRoute: _showRouteDialog,
                      onEditBus: (bus) => _showBusDialog(bus: bus),
                      onStatusFilter: (filter) => ref
                          .read(fleetProvider.notifier)
                          .setStatusFilter(filter),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 3,
                    child: Stack(
                      children: [
                        const Positioned.fill(child: ControlMap()),
                        if (fleet.selectedBus != null)
                          Positioned(
                            right: 16,
                            bottom: 16,
                            child: _SelectedBusCard(
                              bus: fleet.selectedBus!,
                              routeName: fleet.routeName(
                                fleet.selectedBus!.routeId,
                              ),
                              updating: fleet.updating.contains(
                                fleet.selectedBus!.busId,
                              ),
                              onToggle: (visible) => ref
                                  .read(fleetProvider.notifier)
                                  .toggleVisibility(
                                    fleet.selectedBus!.busId,
                                    visible,
                                  ),
                              onEdit: () =>
                                  _showBusDialog(bus: fleet.selectedBus),
                              onDelete: () =>
                                  _confirmDeleteSelected(fleet.selectedBus!),
                              onClose: () => ref
                                  .read(fleetProvider.notifier)
                                  .selectBus(null),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.connection,
    required this.onLogout,
  });

  final FleetConnection connection;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (connection) {
      FleetConnection.connected => ('En línea', AppColors.online),
      FleetConnection.disconnected => ('Sin conexión', AppColors.danger),
      FleetConnection.connecting => ('Conectando…', AppColors.ghost),
    };
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.surfaceRaised,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.border),
            ),
            child: SvgPicture.asset(
              'assets/logo/ya_viene_logo.svg',
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(width: 11),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'YA VIENE',
                style: AppType.ui(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2.5,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                'CONTROL DE FLOTA',
                style: AppType.ui(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.8,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 7),
                Text(
                  label,
                  style: AppType.ui(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          OutlinedButton.icon(
            onPressed: onLogout,
            icon: const Icon(Icons.logout, size: 15),
            label: const Text('Salir'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              side: const BorderSide(color: AppColors.borderStrong),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              textStyle: AppType.ui(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatefulWidget {
  const _TopBar({
    required this.refreshing,
    required this.searchController,
    required this.onSearchChanged,
    required this.onRefresh,
    required this.onToggleAllVisibility,
    required this.allBusesVisible,
  });

  final bool refreshing;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onRefresh;
  final VoidCallback onToggleAllVisibility;
  final bool allBusesVisible;

  @override
  State<_TopBar> createState() => _TopBarState();
}

class _TopBarState extends State<_TopBar> with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  );

  @override
  void didUpdateWidget(_TopBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refreshing && !oldWidget.refreshing) {
      _spin.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 14),
      child: Row(
        children: [
          Text(
            'Flota',
            style: AppType.ui(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
              color: AppColors.textPrimary,
            ),
          ),
          const Spacer(),
          SizedBox(
            width: 260,
            child: TextField(
              controller: widget.searchController,
              onChanged: widget.onSearchChanged,
              style: AppType.ui(fontSize: 13.5),
              decoration: const InputDecoration(
                hintText: 'Buscar placa, ruta o conductor…',
                prefixIcon: Icon(Icons.search, color: AppColors.textMuted, size: 19),
                fillColor: AppColors.surface,
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 10),
          IconButton(
            onPressed: widget.refreshing ? null : widget.onRefresh,
            icon: RotationTransition(
              turns: _spin,
              child: const Icon(
                Icons.refresh,
                size: 20,
                color: AppColors.textSecondary,
              ),
            ),
            tooltip: 'Actualizar flota',
            style: IconButton.styleFrom(
              backgroundColor: AppColors.surface,
              side: const BorderSide(color: AppColors.border),
            ),
          ),
          const SizedBox(width: 10),
          IconButton(
            onPressed: widget.onToggleAllVisibility,
            icon: Icon(
              widget.allBusesVisible ? Icons.visibility_off : Icons.visibility,
              size: 20,
              color: AppColors.textSecondary,
            ),
            tooltip: widget.allBusesVisible
                ? 'Ocultar todos los buses'
                : 'Mostrar todos los buses',
            style: IconButton.styleFrom(
              backgroundColor: AppColors.surface,
              side: const BorderSide(color: AppColors.border),
            ),
          ),
          const SizedBox(width: 14),
          const ClockWidget(
            timeColor: AppColors.textPrimary,
            dateColor: AppColors.textMuted,
          ),
        ],
      ),
    );
  }
}

class _RouteFilters extends StatefulWidget {
  const _RouteFilters({
    required this.fleet,
    required this.onSelect,
  });

  final FleetState fleet;
  final ValueChanged<String?> onSelect;

  @override
  State<_RouteFilters> createState() => _RouteFiltersState();
}

class _RouteFiltersState extends State<_RouteFilters> {
  final _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fleet = widget.fleet;
    return Listener(
      onPointerSignal: (event) {
        if (event is PointerScrollEvent && _controller.hasClients) {
          final next = (_controller.offset + event.scrollDelta.dy)
              .clamp(0.0, _controller.position.maxScrollExtent);
          if (next != _controller.offset) {
            _controller.jumpTo(next);
          }
        }
      },
      child: Scrollbar(
        controller: _controller,
        interactive: true,
        thumbVisibility: false,
        thickness: 4,
        radius: const Radius.circular(AppRadius.pill),
        child: SizedBox(
          height: 42,
          child: ListView(
            controller: _controller,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(bottom: 9),
            children: [
              ...fleet.routes.map(
                (route) => Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: _FilterChip(
                    label: '${route.name} (${route.total})',
                    active: fleet.routeFilter == route.routeId,
                    onTap: () => widget.onSelect(route.routeId),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? AppColors.navy : AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(
              color: active ? AppColors.navy : AppColors.borderStrong,
            ),
          ),
          child: Text(
            label,
            style: AppType.ui(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: active ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _FleetPanel extends ConsumerWidget {
  const _FleetPanel({
    required this.buses,
    required this.fleet,
    required this.onAddBus,
    required this.onAddRoute,
    required this.onEditBus,
    required this.onStatusFilter,
  });

  final List<FleetBus> buses;
  final FleetState fleet;
  final VoidCallback onAddBus;
  final VoidCallback onAddRoute;
  final ValueChanged<FleetBus> onEditBus;
  final ValueChanged<FleetStatusFilter> onStatusFilter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 10),
            child: Row(
              children: [
                Text(
                  'BUSES',
                  style: AppType.ui(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.navy.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    '${buses.length}',
                    style: AppType.ui(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.navy,
                    ),
                  ),
                ),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: onAddRoute,
                  icon: const Icon(Icons.add_road, size: 16),
                  label: const Text('Agregar ruta'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: const BorderSide(color: AppColors.borderStrong),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    textStyle: AppType.ui(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: onAddBus,
                  icon: const Icon(Icons.add, size: 17),
                  label: const Text('Agregar bus'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.online,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    textStyle: AppType.ui(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 9,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: _StatusTabs(
              fleet: fleet,
              onSelect: onStatusFilter,
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Divider(height: 1),
          ),
          Expanded(
            child: buses.isEmpty
                ? Center(
                    child: Text(
                      _emptyMessage(),
                      style: AppType.ui(
                        color: AppColors.textMuted,
                        fontSize: 13,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: buses.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final bus = buses[index];
                      return FleetListTile(
                        bus: bus,
                        selected: fleet.selectedBusId == bus.busId,
                        updating: fleet.updating.contains(bus.busId),
                        routeName: fleet.routeName(bus.routeId),
                        onTap: () =>
                            ref.read(fleetProvider.notifier).selectBus(bus.busId),
                        onToggle: (visible) => ref
                            .read(fleetProvider.notifier)
                            .toggleVisibility(bus.busId, visible),
                        onEdit: () => onEditBus(bus),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String _emptyMessage() {
    if (fleet.routeFilter == null) return 'Selecciona una ruta';
    if (fleet.statusFilter != FleetStatusFilter.all) {
      return switch (fleet.statusFilter) {
        FleetStatusFilter.online => 'Ningún bus en línea en esta ruta',
        FleetStatusFilter.hidden => 'Ningún bus oculto en esta ruta',
        FleetStatusFilter.offline => 'Ningún bus sin señal en esta ruta',
        FleetStatusFilter.all => 'Sin buses registrados',
      };
    }
    return 'Sin buses registrados';
  }
}

class _StatusTabs extends StatelessWidget {
  const _StatusTabs({required this.fleet, required this.onSelect});

  final FleetState fleet;
  final ValueChanged<FleetStatusFilter> onSelect;

  @override
  Widget build(BuildContext context) {
    final tabs = <(FleetStatusFilter, String, int)>[
      (FleetStatusFilter.all, 'Todos', fleet.totalBuses),
      (FleetStatusFilter.online, 'En Línea', fleet.onlineBuses),
      (FleetStatusFilter.hidden, 'Ocultos', fleet.hiddenBuses),
      (FleetStatusFilter.offline, 'Sin Señal', fleet.offlineBuses),
    ];
    return Row(
      children: [
        for (final (filter, label, count) in tabs) ...[
          _StatusTab(
            label: label,
            count: count,
            active: fleet.statusFilter == filter,
            onTap: () => onSelect(filter),
          ),
          const SizedBox(width: 6),
        ],
      ],
    );
  }
}

class _StatusTab extends StatelessWidget {
  const _StatusTab({
    required this.label,
    required this.count,
    required this.active,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? AppColors.navy : Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: AppType.ui(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: active ? Colors.white : AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                '$count',
                style: AppType.ui(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: active ? Colors.white70 : AppColors.textMuted,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectedBusCard extends StatelessWidget {
  const _SelectedBusCard({
    required this.bus,
    required this.routeName,
    required this.updating,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
    required this.onClose,
  });

  final FleetBus bus;
  final String? routeName;
  final bool updating;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final (statusLabel, statusColor) = _status(bus);
    return Container(
      width: 292,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(Icons.directions_bus, color: statusColor, size: 19),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bus.placa.isEmpty ? bus.busId : bus.placa,
                      style: AppType.ui(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      statusLabel,
                      style: AppType.mono(
                        fontSize: 10.5,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: AppColors.textMuted, size: 18),
                onPressed: onClose,
                tooltip: 'Cerrar',
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          if (routeName != null || bus.driverName != null) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (routeName != null)
                  _infoChip(icon: Icons.route, label: routeName!, color: AppColors.navy),
                if (bus.driverName != null)
                  _infoChip(
                    icon: Icons.person_outline,
                    label: bus.driverName!,
                    color: AppColors.textSecondary,
                  ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: updating ? null : () => onToggle(!bus.visible),
                  icon: Icon(
                    bus.visible ? Icons.visibility_off : Icons.visibility,
                    size: 16,
                  ),
                  label: Text(bus.visible ? 'Ocultar' : 'Mostrar'),
                  style: FilledButton.styleFrom(
                    backgroundColor:
                        bus.visible ? AppColors.hidden : AppColors.online,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    textStyle: AppType.ui(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                    minimumSize: const Size(0, 40),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 18),
                tooltip: 'Editar bus',
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.surfaceRaised,
                  side: const BorderSide(color: AppColors.border),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(
                  Icons.delete_outline,
                  size: 18,
                  color: AppColors.danger,
                ),
                tooltip: 'Eliminar bus de la flota',
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.danger.withValues(alpha: 0.08),
                  side: BorderSide(color: AppColors.danger.withValues(alpha: 0.25)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: AppType.ui(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  (String, Color) _status(FleetBus bus) {
    if (!bus.online) return ('Sin señal', AppColors.offline);
    if (bus.isGhost) return ('Inactivo', AppColors.ghost);
    return ('En línea', AppColors.online);
  }
}

class _ErrorBanner extends ConsumerWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      color: AppColors.danger.withValues(alpha: 0.08),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.danger, size: 17),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: AppType.ui(
                color: AppColors.danger,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () => ref.read(fleetProvider.notifier).refresh(),
            child: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }
}
