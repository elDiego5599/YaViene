import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/fleet_bus.dart';
import '../../../../shared/widgets/clock_widget.dart';
import '../providers/fleet_providers.dart';
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

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final fleet = ref.watch(fleetProvider);
    final session = auth.session;

    final buses = fleet.fleetList.where((b) {
      if (_query.isEmpty) return true;
      final q = _query.toLowerCase();
      return b.busId.toLowerCase().contains(q) || (b.routeId?.toLowerCase().contains(q) ?? false);
    }).toList();

    return Scaffold(
      body: Column(
        children: [
          _Header(
            companyName: session?.companyName ?? 'Flota',
            connection: fleet.connection,
            onlineCount: fleet.buses.values.where((b) => b.online && b.visible).length,
            onLogout: () {
              ref.read(fleetProvider.notifier).dispose();
              ref.read(authProvider.notifier).logout();
              context.go('/login');
            },
          ),
          if (fleet.error != null) _ErrorBanner(message: fleet.error!),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 360,
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    border: Border(right: BorderSide(color: AppColors.border)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                        child: TextField(
                          controller: _searchController,
                          onChanged: (v) => setState(() => _query = v),
                          decoration: const InputDecoration(
                            hintText: 'Buscar bus o ruta…',
                            prefixIcon: Icon(Icons.search, color: AppColors.textMuted, size: 20),
                            contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                        child: Row(
                          children: [
                            Text(
                              'FLOTA',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 2,
                                color: AppColors.textMuted,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.panelGlass,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '${buses.length}',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.refresh, color: AppColors.textSecondary, size: 20),
                              tooltip: 'Actualizar flota',
                              onPressed: () => ref.read(fleetProvider.notifier).refresh(),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: buses.isEmpty
                            ? Center(
                                child: Text(
                                  _query.isEmpty ? 'Sin buses registrados' : 'Sin resultados',
                                  style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13),
                                ),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.all(14),
                                itemCount: buses.length,
                                separatorBuilder: (_, _) => const SizedBox(height: 8),
                                itemBuilder: (context, index) {
                                  final bus = buses[index];
                                  return FleetListTile(
                                    bus: bus,
                                    selected: fleet.selectedBusId == bus.busId,
                                    updating: fleet.updating.contains(bus.busId),
                                    onTap: () => ref.read(fleetProvider.notifier).selectBus(bus.busId),
                                    onToggle: (visible) => ref
                                        .read(fleetProvider.notifier)
                                        .toggleVisibility(bus.busId, visible),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Stack(
                    children: [
                      const Positioned.fill(child: ControlMap()),
                      if (fleet.selectedBus != null)
                        Positioned(
                          right: 18,
                          bottom: 18,
                          child: _SelectedBusCard(
                            bus: fleet.selectedBus!,
                            updating: fleet.updating.contains(fleet.selectedBus!.busId),
                            onToggle: (visible) => ref
                                .read(fleetProvider.notifier)
                                .toggleVisibility(fleet.selectedBus!.busId, visible),
                            onClose: () => ref.read(fleetProvider.notifier).selectBus(null),
                          ),
                        ),
                    ],
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

class _ErrorBanner extends ConsumerWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      color: AppColors.danger.withValues(alpha: 0.12),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.danger, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.inter(color: AppColors.danger, fontSize: 13, fontWeight: FontWeight.w600),
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

class _Header extends StatelessWidget {
  const _Header({
    required this.companyName,
    required this.connection,
    required this.onlineCount,
    required this.onLogout,
  });

  final String companyName;
  final FleetConnection connection;
  final int onlineCount;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (connection) {
      FleetConnection.connected => ('En línea', AppColors.online),
      FleetConnection.disconnected => ('Sin conexión', AppColors.danger),
      FleetConnection.connecting => ('Conectando…', AppColors.warmAmber),
    };
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppColors.online, Color(0xFF00C465)]),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.directions_bus, color: Color(0xFF0C0C0F), size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                companyName,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.2,
                ),
              ),
              Text(
                'Control de flota · $onlineCount activos',
                style: GoogleFonts.inter(fontSize: 11.5, color: AppColors.textMuted),
              ),
            ],
          ),
          const SizedBox(width: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: color.withValues(alpha: 0.45)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: GoogleFonts.inter(color: color, fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          const Spacer(),
          const ClockWidget(),
          const SizedBox(width: 22),
          TextButton.icon(
            onPressed: onLogout,
            icon: const Icon(Icons.logout, size: 17),
            label: const Text('Salir'),
          ),
        ],
      ),
    );
  }
}

class _SelectedBusCard extends StatelessWidget {
  const _SelectedBusCard({
    required this.bus,
    required this.updating,
    required this.onToggle,
    required this.onClose,
  });

  final FleetBus bus;
  final bool updating;
  final ValueChanged<bool> onToggle;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final (statusLabel, statusColor) = _status(bus);
    return Container(
      width: 300,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderStrong),
        boxShadow: const [
          BoxShadow(color: Color(0x66000000), blurRadius: 24, offset: Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.directions_bus, color: statusColor, size: 19),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bus.busId,
                    style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                  ),
                  Text(
                    '${bus.routeId ?? 'Sin ruta'} · $statusLabel',
                    style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, color: AppColors.textMuted, size: 18),
                onPressed: onClose,
                tooltip: 'Cerrar',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                'Visibilidad',
                style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              if (bus.lat != null && bus.lon != null)
                Text(
                  '${bus.lat!.toStringAsFixed(5)}, ${bus.lon!.toStringAsFixed(5)}',
                  style: GoogleFonts.inter(fontSize: 10.5, color: AppColors.textMuted),
                ),
            ],
          ),
          const SizedBox(height: 4),
          updating
              ? const SizedBox(
                  height: 32,
                  child: Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))),
                )
              : FilledButton.icon(
                  onPressed: () => onToggle(!bus.visible),
                  icon: Icon(bus.visible ? Icons.visibility_off : Icons.visibility, size: 18),
                  label: Text(bus.visible ? 'Ocultar bus' : 'Mostrar bus'),
                  style: FilledButton.styleFrom(
                    backgroundColor: bus.visible ? AppColors.hidden : AppColors.online,
                    minimumSize: const Size.fromHeight(42),
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
