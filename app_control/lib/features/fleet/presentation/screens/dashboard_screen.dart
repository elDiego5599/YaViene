import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../providers/fleet_providers.dart';
import '../widgets/control_map.dart';
import '../widgets/fleet_list_tile.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(fleetProvider.notifier).start();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final fleet = ref.watch(fleetProvider);
    final session = auth.session;

    return Scaffold(
      body: Column(
        children: [
          _Header(
            companyName: session?.companyName ?? 'Flota',
            connection: fleet.connection,
            onLogout: () {
              ref.read(fleetProvider.notifier).dispose();
              ref.read(authProvider.notifier).logout();
              context.go('/login');
            },
          ),
          if (fleet.error != null)
            MaterialBanner(
              backgroundColor: Colors.red.shade50,
              content: Text(fleet.error!, style: const TextStyle(color: Color(0xFFDC2626))),
              actions: [
                TextButton(
                  onPressed: () => ref.read(fleetProvider.notifier).refresh(),
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 340,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                        child: Row(
                          children: [
                            Text(
                              'Flota (${fleet.buses.length})',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.refresh),
                              tooltip: 'Actualizar',
                              onPressed: () => ref.read(fleetProvider.notifier).refresh(),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: fleet.buses.isEmpty
                            ? const Center(child: Text('Sin buses registrados'))
                            : ListView.separated(
                                padding: const EdgeInsets.all(12),
                                itemCount: fleet.fleetList.length,
                                separatorBuilder: (_, _) => const SizedBox(height: 8),
                                itemBuilder: (context, index) {
                                  final bus = fleet.fleetList[index];
                                  return FleetListTile(
                                    bus: bus,
                                    updating: fleet.updating.contains(bus.busId),
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
                const VerticalDivider(width: 1),
                const Expanded(child: ControlMap()),
              ],
            ),
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
    required this.onLogout,
  });

  final String companyName;
  final FleetConnection connection;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (connection) {
      FleetConnection.connected => ('Conectado', const Color(0xFF059669)),
      FleetConnection.disconnected => ('Sin conexión', const Color(0xFFDC2626)),
      FleetConnection.connecting => ('Conectando…', Colors.orange.shade700),
    };
    return Container(
      color: const Color(0xFF14274E),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.directions_bus, color: Colors.white),
          const SizedBox(width: 10),
          Text(
            companyName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: onLogout,
            icon: const Icon(Icons.logout, color: Colors.white, size: 18),
            label: const Text('Salir', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
