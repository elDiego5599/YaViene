import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import '../../../../core/utils/bus_labels.dart';
import '../../../map/presentation/providers/tracking_providers.dart';
import '../../../map/presentation/providers/user_location_provider.dart';
import '../../../map/presentation/utils/geo.dart';
import '../providers/alert_history_provider.dart';
import '../providers/proximity_alerts_provider.dart';

/// Centro de avisos: los avisos activos (esperando la notificación) y el
/// historial de los ya enviados. Permite desactivar, borrar de a uno o
/// borrar todo; borrar un aviso activo lo desactiva.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(alertHistoryProvider);
    final route = ref.watch(selectedRouteProvider);
    final location = ref.watch(userLocationProvider);
    // Sin ruta activa no hay buses que consultar (ni suscripción a '').
    final positions = route == null
        ? const <BusPosition>[]
        : ref.watch(busPositionsSourceProvider(route.id).select(
            (value) => value.value ?? const <BusPosition>[],
          ));

    // Orden editorial: primero los activos, luego los enviados. El orden de
    // persistencia se conserva para que la selección sea estable.
    final entries = [
      ...history.where((e) => !e.sent),
      ...history.where((e) => e.sent),
    ].toList();

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
            color: AppColors.textPrimary,
            letterSpacing: -0.3,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          color: AppColors.textPrimary,
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: entries.isEmpty ? null : [const _SelectAction()],
      ),
      body: entries.isEmpty
          ? const _EmptyState()
          : _HistoryList(
              entries: entries,
              positions: positions,
              location: location,
              route: route,
            ),
    );
  }
}

/// Acción "Seleccionar"/"Borrar todas" en la barra superior.
class _SelectAction extends ConsumerWidget {
  const _SelectAction();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(alertSelectionProvider);
    final selecting = selection.active;

    return TextButton(
      onPressed: () {
        if (selecting) {
          // Borrar todo: los activos se desactivan, el historial se limpia.
          final notifier = ref.read(proximityAlertsProvider.notifier);
          for (final e in ref.read(alertHistoryProvider)) {
            if (!e.sent) {
              ref.read(activeAlertsProvider.notifier).deactivateAlert(e.busId);
              notifier.disarmAlert(e.busId);
            }
          }
          ref.read(alertHistoryProvider.notifier).clearAll();
          ref.read(alertSelectionProvider.notifier).clear();
        } else {
          ref.read(alertSelectionProvider.notifier).enter();
        }
      },
      style: TextButton.styleFrom(
        foregroundColor:
            selecting ? AppColors.error : AppColors.primaryDeep,
        disabledForegroundColor: AppColors.textDisabled,
      ),
      child: Text(
        selecting ? 'Borrar todas' : 'Seleccionar',
        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
      ),
    );
  }
}

/// Estado del modo selección: activo o no, y el conjunto de busIds marcados.
class _SelectionState {
  final bool active;
  final Set<String> selected;

  const _SelectionState(this.active, this.selected);
}

class _SelectionNotifier extends StateNotifier<_SelectionState> {
  _SelectionNotifier() : super(const _SelectionState(false, {}));

  void enter() => state = const _SelectionState(true, {});

  void toggle(String busId) {
    final next = {...state.selected};
    if (!next.add(busId)) next.remove(busId);
    state = _SelectionState(true, next);
  }

  void clear() => state = const _SelectionState(false, {});
}

final alertSelectionProvider =
    StateNotifierProvider<_SelectionNotifier, _SelectionState>(
        (ref) => _SelectionNotifier());

class _HistoryList extends ConsumerWidget {
  final List<AlertHistoryEntry> entries;
  final List<BusPosition> positions;
  final UserLocationState location;
  final RouteInfo? route;

  const _HistoryList({
    required this.entries,
    required this.positions,
    required this.location,
    required this.route,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(alertSelectionProvider);
    final selecting = selection.active;
    final selected = selection.selected;

    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            itemCount: entries.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final entry = entries[index];
              final pos = positions.cast<BusPosition?>().firstWhere(
                    (p) => p?.busId == entry.busId,
                    orElse: () => null,
                  );
              final distanceMeters =
                  !entry.sent && pos != null && location.hasPosition
                      ? haversineMeters(
                              location.lat!, location.lon!, pos.lat, pos.lon)
                          .round()
                      : null;
              return _TileEntrance(
                child: _AlertTile(
                  entry: entry,
                  routeName: entry.routeName ??
                      (route?.id == entry.routeId ? route?.name : null),
                  distanceMeters: distanceMeters,
                  selecting: selecting,
                  selected: selected.contains(entry.busId),
                  onToggleSelect: () => ref
                      .read(alertSelectionProvider.notifier)
                      .toggle(entry.busId),
                  onDisable: () {
                    ref
                        .read(activeAlertsProvider.notifier)
                        .deactivateAlert(entry.busId);
                    ref
                        .read(proximityAlertsProvider.notifier)
                        .disarmAlert(entry.busId);
                    ref.read(alertHistoryProvider.notifier).remove(entry.busId);
                  },
                ),
              );
            },
          ),
        ),
        // Barra de acciones del modo selección.
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          child: selecting
              ? Container(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  child: SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        disabledBackgroundColor: AppColors.divider,
                        disabledForegroundColor: AppColors.textDisabled,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      onPressed: selected.isEmpty
                          ? null
                          : () {
                              final notifier =
                                  ref.read(proximityAlertsProvider.notifier);
                              for (final busId in selected) {
                                ref
                                    .read(activeAlertsProvider.notifier)
                                    .deactivateAlert(busId);
                                notifier.disarmAlert(busId);
                                ref
                                    .read(alertHistoryProvider.notifier)
                                    .remove(busId);
                              }
                              ref.read(alertSelectionProvider.notifier).clear();
                            },
                      icon: const Icon(Icons.delete_outline_rounded, size: 20),
                      label: Text(
                        selected.isEmpty
                            ? 'Selecciona avisos'
                            : 'Borrar ${selected.length}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

/// Entrada suave de cada tile del historial: aparece con un fundido y un
/// pequeño deslizamiento hacia arriba al montarse (una sola vez, sin timers).
class _TileEntrance extends StatefulWidget {
  final Widget child;

  const _TileEntrance({required this.child});

  @override
  State<_TileEntrance> createState() => _TileEntranceState();
}

class _TileEntranceState extends State<_TileEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _anim = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.06),
          end: Offset.zero,
        ).animate(_anim),
        child: widget.child,
      ),
    );
  }
}

class _AlertTile extends StatelessWidget {
  final AlertHistoryEntry entry;
  final String? routeName;
  final int? distanceMeters;
  final bool selecting;
  final bool selected;
  final VoidCallback onToggleSelect;
  final VoidCallback onDisable;

  const _AlertTile({
    required this.entry,
    required this.routeName,
    required this.distanceMeters,
    required this.selecting,
    required this.selected,
    required this.onToggleSelect,
    required this.onDisable,
  });

  @override
  Widget build(BuildContext context) {
    final sent = entry.sent;
    final subtitle = sent
        ? 'Notificación enviada · ${_formatTime(entry.sentAt!)}'
        : distanceMeters != null
            ? 'Está a $distanceMeters m de tu ubicación · esperando aviso'
            : 'Esperando señal del bus';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selected ? AppColors.primaryDeep : AppColors.divider,
          width: selected ? 1.5 : 1.0,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: sent ? AppColors.warningLight : const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              sent
                  ? Icons.notifications_active_rounded
                  : Icons.directions_bus_filled_rounded,
              color: sent ? AppColors.warning : AppColors.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  routePlateLabel(
                    busId: entry.busId,
                    routeName: routeName,
                    routeId: entry.routeId,
                  ),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.3,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (selecting)
            Checkbox(
              value: selected,
              onChanged: (_) => onToggleSelect(),
              activeColor: AppColors.primaryDeep,
              visualDensity: VisualDensity.compact,
            )
          else if (sent)
            const Text(
              'Enviado',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.textDisabled,
              ),
            )
          else
            TextButton(
              onPressed: onDisable,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.error,
              ),
              child: const Text(
                'Desactivar',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
              ),
            ),
        ],
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
                color: AppColors.primary,
                size: 36,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No tienes avisos activos',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
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
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatTime(DateTime d) {
  const months = [
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sep',
    'oct',
    'nov',
    'dic',
  ];
  final h = d.hour.toString().padLeft(2, '0');
  final m = d.minute.toString().padLeft(2, '0');
  return '${d.day} ${months[d.month - 1]} · $h:$m';
}
