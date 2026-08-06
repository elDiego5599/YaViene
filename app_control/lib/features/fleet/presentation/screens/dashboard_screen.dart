import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../../shared/widgets/clock_widget.dart';
import '../../domain/fleet_bus.dart';
import '../providers/fleet_providers.dart';
import '../widgets/bus_dialog.dart';
import '../widgets/control_map.dart';
import '../widgets/fleet_list_tile.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(fleetProvider.notifier).start();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    await ref.read(authProvider.notifier).logout();
    if (mounted) context.go('/login');
  }

  void _showBusDialog({FleetBus? bus}) {
    showDialog<void>(
      context: context,
      builder: (_) => BusDialog(bus: bus),
    );
  }

  Future<void> _confirmDelete(FleetBus bus) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Eliminar bus',
          style: GoogleFonts.inter(
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Text(
          '¿Eliminar ${bus.placa.isEmpty ? bus.busId : bus.placa} del catálogo? '
          'Los pasajeros dejarán de verlo de inmediato.',
          style: GoogleFonts.inter(fontSize: 13.5, height: 1.5),
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
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: GoogleFonts.inter(
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
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final fleet = ref.watch(fleetProvider);

    final buses = fleet.fleetList.where((b) {
      if (_query.isEmpty) return true;
      final q = _query.toLowerCase();
      return b.busId.toLowerCase().contains(q) ||
          b.placa.toLowerCase().contains(q) ||
          (b.routeId?.toLowerCase().contains(q) ?? false) ||
          (b.driverName?.toLowerCase().contains(q) ?? false);
    }).toList();

    return Scaffold(
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Sidebar(
            companyName: auth.session?.companyName ?? 'Mi empresa',
            connection: fleet.connection,
            onLogout: _logout,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _TopBar(
                  total: fleet.totalBuses,
                  online: fleet.onlineBuses,
                  searchController: _searchController,
                  onSearchChanged: (v) => setState(() => _query = v),
                  onRefresh: () => ref.read(fleetProvider.notifier).refresh(),
                ),
                if (fleet.error != null) _ErrorBanner(message: fleet.error!),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 4, 24, 14),
                  child: _StatsRow(fleet: fleet),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _RouteFilters(
                    fleet: fleet,
                    onSelect: (routeId) =>
                        ref.read(fleetProvider.notifier).setRouteFilter(routeId),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 14, 24, 24),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          flex: 2,
                          child: _FleetPanel(
                            buses: buses,
                            fleet: fleet,
                            onAddBus: () => _showBusDialog(),
                            onEditBus: (bus) => _showBusDialog(bus: bus),
                            onDeleteBus: _confirmDelete,
                          ),
                        ),
                        const SizedBox(width: 16),
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
                                        _confirmDelete(fleet.selectedBus!),
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
          ),
        ],
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.companyName,
    required this.connection,
    required this.onLogout,
  });

  final String companyName;
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
      width: 224,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(right: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceRaised,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: SvgPicture.asset(
                    'assets/logo/ya_viene_logo.svg',
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'YA VIENE',
                        style: GoogleFonts.inter(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2.5,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'CONTROL DE FLOTA',
                        style: GoogleFonts.inter(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.8,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
            child: _NavItem(
              icon: Icons.grid_view_rounded,
              label: 'FLOTA',
              active: true,
            ),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceRaised,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          label,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  companyName,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: onLogout,
                  icon: const Icon(Icons.logout, size: 16),
                  label: const Text('Salir'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: const BorderSide(color: AppColors.borderStrong),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: GoogleFonts.inter(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
  });

  final IconData icon;
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: active ? AppColors.navy.withValues(alpha: 0.08) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 17, color: active ? AppColors.navy : AppColors.textMuted),
          const SizedBox(width: 10),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.8,
              color: active ? AppColors.navy : AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.total,
    required this.online,
    required this.searchController,
    required this.onSearchChanged,
    required this.onRefresh,
  });

  final int total;
  final int online;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 14),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Flota',
                style: GoogleFonts.inter(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                '$total buses · $online en ruta ahora',
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const Spacer(),
          SizedBox(
            width: 260,
            child: TextField(
              controller: searchController,
              onChanged: onSearchChanged,
              style: GoogleFonts.inter(fontSize: 13.5),
              decoration: const InputDecoration(
                hintText: 'Buscar placa, bus, ruta o conductor…',
                prefixIcon: Icon(Icons.search, color: AppColors.textMuted, size: 19),
                fillColor: AppColors.surface,
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 10),
          IconButton(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh, size: 20, color: AppColors.textSecondary),
            tooltip: 'Actualizar flota',
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

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.fleet});

  final FleetState fleet;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatCard(
          label: 'TOTAL FLOTA',
          value: fleet.totalBuses,
          icon: Icons.directions_bus,
          color: AppColors.navy,
        ),
        const SizedBox(width: 12),
        _StatCard(
          label: 'EN RUTA',
          value: fleet.onlineBuses,
          icon: Icons.navigation,
          color: AppColors.online,
        ),
        const SizedBox(width: 12),
        _StatCard(
          label: 'OCULTOS',
          value: fleet.hiddenBuses,
          icon: Icons.visibility_off,
          color: AppColors.hidden,
        ),
        const SizedBox(width: 12),
        _StatCard(
          label: 'SIN SEÑAL',
          value: fleet.offlineBuses,
          icon: Icons.signal_wifi_off,
          color: AppColors.offline,
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final int value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, size: 19, color: color),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.6,
                    color: AppColors.textMuted,
                  ),
                ),
                Text(
                  '$value',
                  style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    color: AppColors.textPrimary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RouteFilters extends StatelessWidget {
  const _RouteFilters({required this.fleet, required this.onSelect});

  final FleetState fleet;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _FilterChip(
            label: 'TODAS',
            active: fleet.routeFilter == null,
            onTap: () => onSelect(null),
          ),
          ...fleet.routes.map(
            (route) => Padding(
              padding: const EdgeInsets.only(left: 8),
              child: _FilterChip(
                label: '${route.routeId} · ${route.name} (${route.total})',
                active: fleet.routeFilter == route.routeId,
                onTap: () => onSelect(route.routeId),
              ),
            ),
          ),
        ],
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
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: active ? AppColors.navy : AppColors.borderStrong,
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.inter(
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
    required this.onEditBus,
    required this.onDeleteBus,
  });

  final List<FleetBus> buses;
  final FleetState fleet;
  final VoidCallback onAddBus;
  final ValueChanged<FleetBus> onEditBus;
  final ValueChanged<FleetBus> onDeleteBus;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
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
                  style: GoogleFonts.inter(
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
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${buses.length}',
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.navy,
                    ),
                  ),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: onAddBus,
                  icon: const Icon(Icons.add, size: 17),
                  label: const Text('Agregar bus'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.online,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    textStyle: GoogleFonts.inter(
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
          Expanded(
            child: buses.isEmpty
                ? Center(
                    child: Text(
                      fleet.routeFilter != null
                          ? 'Sin buses en esta ruta'
                          : 'Sin buses registrados',
                      style: GoogleFonts.inter(
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
                        onDelete: () => onDeleteBus(bus),
                      );
                    },
                  ),
          ),
        ],
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
        borderRadius: BorderRadius.circular(16),
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
                  borderRadius: BorderRadius.circular(10),
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
                      style: GoogleFonts.inter(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      '${bus.busId} · $statusLabel',
                      style: GoogleFonts.jetBrainsMono(
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
                      borderRadius: BorderRadius.circular(10),
                    ),
                    textStyle: GoogleFonts.inter(
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
                tooltip: 'Eliminar bus',
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
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.inter(
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
              style: GoogleFonts.inter(
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
