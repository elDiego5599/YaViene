import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import '../providers/map_view_state.dart';
import '../providers/tracking_providers.dart';

class EtaBottomSheet extends ConsumerStatefulWidget {
  const EtaBottomSheet({super.key});

  @override
  ConsumerState<EtaBottomSheet> createState() => _EtaBottomSheetState();
}

class _EtaBottomSheetState extends ConsumerState<EtaBottomSheet> {
  static const double _expandedMapInset = 338;
  static const double _collapsedMapInset = 166;
  bool _isExpanded = true;
  double _lastPublishedInset = -1;

  void _toggleSheet() {
    setState(() => _isExpanded = !_isExpanded);
    _publishMapInset();
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
    final selectedDirection = ref.watch(selectedSentidoProvider);
    final selectedBuses = ref.watch(selectedBusesProvider);

    _publishMapInset();

    final destination =
        selectedDirection == RouteSentido.ida ? 'Centro' : 'Soledad';

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
                if (selectedBuses.isEmpty)
                  _buildEmptyState()
                else if (selectedBuses.length == 1)
                  _buildSingleBusState(selectedBuses.first, destination)
                else
                  _buildMultiBusState(selectedBuses, destination),
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
                "Selecciona hasta 2 buses para seguir su ETA",
                style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
              ),
            ],
          ),
    );
  }

  Widget _buildSingleBusState(String busId, String destination) {
    final isActive = ref.watch(activeAlertsProvider).contains(busId);

    return Column(
      children: [
        const Text("3",
            style: TextStyle(
                fontSize: 84,
                fontWeight: FontWeight.w200,
                color: Color(0xFF14274E),
                height: 0.9,
                letterSpacing: -3.0)),
        const SizedBox(height: 6),
        Text("minutos para llegar a tu parada \u2022 Bus $busId",
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B))),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          child: _StickyAlertButton(
            isActive: isActive,
            label: isActive ? "ALERTA ACTIVADA" : "AVISARME AL ESTAR CERCA",
            onPressed: () {
              HapticFeedback.mediumImpact();
              ref.read(activeAlertsProvider.notifier).toggleAlert(busId);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMultiBusState(Set<String> buses, String destination) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          ...buses.map((busId) {
            final eta = buses.first == busId ? "3" : "12";
            final isActive = ref.watch(activeAlertsProvider).contains(busId);

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.directions_bus_rounded,
                        color: Color(0xFF14274E), size: 20),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Bus $busId",
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A))),
                        Text("Llega en $eta min",
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF00A859))),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: isActive,
                    activeTrackColor: const Color(0xFF00A859),
                    onChanged: (val) {
                      HapticFeedback.lightImpact();
                      ref.read(activeAlertsProvider.notifier).toggleAlert(busId);
                    },
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _StickyAlertButton extends StatefulWidget {
  final bool isActive;
  final String label;
  final VoidCallback onPressed;

  const _StickyAlertButton({
    required this.isActive,
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
    final backgroundColor =
        widget.isActive ? const Color(0xFF065F46) : const Color(0xFF00A859);

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
              key: ValueKey(widget.isActive),
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  widget.isActive
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
