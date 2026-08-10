import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import '../../../map/presentation/providers/tracking_providers.dart';
import '../../../map/presentation/providers/user_location_provider.dart';
import '../../../map/presentation/utils/geo.dart';
import '../providers/proximity_alerts_provider.dart';

/// Buses con aviso de acercamiento activo. Cada entrada permite desactivar
/// el aviso; cuando la notificación ya se disparó, el bus sale solo de la
/// lista (auto-borrado en [ProximityAlertsNotifier]).
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alerts = ref.watch(activeAlertsProvider);
    final sent = ref.watch(proximityAlertsProvider);
    final route = ref.watch(selectedRouteProvider);
    final location = ref.watch(userLocationProvider);
    // Sin ruta activa no hay buses que consultar (ni suscripción a '').
    final positions = route == null
        ? const <BusPosition>[]
        : ref.watch(busPositionsSourceProvider(route.id).select(
            (value) => value.value ?? const <BusPosition>[],
          ));

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAFC),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Notificaciones',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
            letterSpacing: -0.3,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          color: const Color(0xFF0F172A),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: alerts.isEmpty
          ? const _EmptyState()
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              itemCount: alerts.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final busId = alerts.elementAt(index);
                final pos = positions.cast<BusPosition?>().firstWhere(
                      (p) => p?.busId == busId,
                      orElse: () => null,
                    );
                final wasSent = sent.contains(busId);
                return _AlertTile(
                  busId: busId,
                  wasSent: wasSent,
                  distanceMeters: pos != null && location.hasPosition
                      ? haversineMeters(
                          location.lat!, location.lon!, pos.lat, pos.lon)
                          .round()
                      : null,
                  onDisable: () => ref
                      .read(activeAlertsProvider.notifier)
                      .toggleAlert(busId),
                );
              },
            ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.notifications_none_rounded,
                color: Color(0xFF00A859),
                size: 36,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No tienes avisos activos',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'En el mapa, toca un bus y activa "Avísame" para que te '
              'notifiquemos cuando se acerque a tu ubicación.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlertTile extends StatelessWidget {
  final String busId;
  final bool wasSent;
  final int? distanceMeters;
  final VoidCallback onDisable;

  const _AlertTile({
    required this.busId,
    required this.wasSent,
    required this.distanceMeters,
    required this.onDisable,
  });

  @override
  Widget build(BuildContext context) {
    final subtitle = wasSent
        ? 'El aviso ya se envió y se retiró de la lista'
        : distanceMeters != null
            ? 'Está a $distanceMeters m de tu ubicación · esperando aviso'
            : 'Esperando señal del bus';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              wasSent
                  ? Icons.notifications_active_rounded
                  : Icons.directions_bus_filled_rounded,
              color: wasSent
                  ? const Color(0xFFD97706)
                  : const Color(0xFF00A859),
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bus $busId',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.3,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          TextButton(
            onPressed: wasSent ? null : onDisable,
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFDC2626),
              disabledForegroundColor: const Color(0xFF94A3B8),
            ),
            child: Text(
              wasSent ? 'Enviado' : 'Desactivar',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
