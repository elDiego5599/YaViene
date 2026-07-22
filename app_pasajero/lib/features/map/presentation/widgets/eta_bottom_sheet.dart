import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

class EtaBottomSheet extends ConsumerStatefulWidget {
  const EtaBottomSheet({super.key});

  @override
  ConsumerState<EtaBottomSheet> createState() => _EtaBottomSheetState();
}

class _EtaBottomSheetState extends ConsumerState<EtaBottomSheet>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = true;

  void _toggleSheet() => setState(() => _isExpanded = !_isExpanded);

  @override
  Widget build(BuildContext context) {
    final selectedRoute = ref.watch(selectedRouteProvider);
    final selectedDirection = ref.watch(selectedSentidoProvider);
    final alertActive = ref.watch(proximityAlertProvider);

    if (selectedRoute == null) return const SizedBox.shrink();

    final destination =
        selectedDirection == RouteSentido.ida ? 'Centro' : 'Soledad';

    return GestureDetector(
      onVerticalDragEnd: (details) {
        if (details.primaryVelocity! > 0 && _isExpanded) {
          _toggleSheet();
        } else if (details.primaryVelocity! < 0 && !_isExpanded) {
          _toggleSheet();
        }
      },
      child: AnimatedSize(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        alignment: Alignment.bottomCenter,
        child: Container(
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
                
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.directions_bus_rounded,
                          color: Color(0xFF14274E),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF00A859),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'EN TIEMPO REAL',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF00A859),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              destination,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                                letterSpacing: -0.5,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: AnimatedRotation(
                          turns: _isExpanded ? 0.5 : 0.0,
                          duration: const Duration(milliseconds: 250),
                          child: const Icon(
                            Icons.keyboard_arrow_up_rounded,
                            color: Color(0xFF64748B),
                            size: 28,
                          ),
                        ),
                        onPressed: _toggleSheet,
                      ),
                    ],
                  ),
                ),
                
                if (_isExpanded) ...[
                  const SizedBox(height: 28),
                  Column(
                    children: [
                      const Text(
                        '3',
                        style: TextStyle(
                          fontSize: 84,
                          fontWeight: FontWeight.w200,
                          color: Color(0xFF14274E),
                          height: 0.9,
                          letterSpacing: -3.0,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'minutos para llegar a tu parada',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF64748B),
                          letterSpacing: -0.2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                ] else ...[
                  const SizedBox(height: 20),
                ],

                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                  child: _StickyAlertButton(
                    isActive: alertActive,
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      final next = !alertActive;
                      ref.read(proximityAlertProvider.notifier).state = next;
                    },
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

class _StickyAlertButton extends StatefulWidget {
  final bool isActive;
  final VoidCallback onPressed;

  const _StickyAlertButton({
    required this.isActive,
    required this.onPressed,
  });

  @override
  State<_StickyAlertButton> createState() => _StickyAlertButtonState();
}

class _StickyAlertButtonState extends State<_StickyAlertButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = widget.isActive ? const Color(0xFF0F172A) : const Color(0xFF00A859);

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
            boxShadow: widget.isActive ? [] : [
              BoxShadow(
                color: const Color(0xFF00A859).withValues(alpha: 0.25),
                blurRadius: 20,
                offset: const Offset(0, 8),
              )
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
                  widget.isActive
                      ? 'ALERTA ACTIVADA'
                      : 'AVISARME AL ESTAR CERCA',
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
