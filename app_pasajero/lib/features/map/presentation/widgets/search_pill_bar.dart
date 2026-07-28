import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import 'route_selector_sheet.dart';

class SearchPillBar extends ConsumerStatefulWidget {
  const SearchPillBar({super.key});

  @override
  ConsumerState<SearchPillBar> createState() => _SearchPillBarState();
}

class _SearchPillBarState extends ConsumerState<SearchPillBar> {
  bool _menuPressed = false;
  bool _actionPressed = false;

  void _onMenuTap() {
    HapticFeedback.lightImpact();
    Scaffold.of(context).openDrawer();
  }

  void _onSearchTap() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const RouteSelectorSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedRoute = ref.watch(selectedRouteProvider);

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Container(
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF14274E).withValues(alpha: 0.08),
                blurRadius: 24,
                offset: const Offset(0, 8),
              )
            ],
          ),
          child: Row(
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _onMenuTap,
                onTapDown: (_) => setState(() => _menuPressed = true),
                onTapUp: (_) => setState(() => _menuPressed = false),
                onTapCancel: () => setState(() => _menuPressed = false),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    shape: BoxShape.circle,
                    boxShadow: _menuPressed
                        ? [
                            BoxShadow(
                              color: const Color(0xFF14274E).withValues(alpha: 0.15),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            )
                          ]
                        : null,
                  ),
                  child: const Icon(
                    Icons.menu_rounded,
                    color: Color(0xFF14274E),
                    size: 22,
                  ),
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _onSearchTap,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          if (selectedRoute != null) ...[
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Color(0xFF00A859),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Expanded(
                            child: Text(
                              selectedRoute?.name ?? "¿Qué bus esperas?",
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                                letterSpacing: -0.4,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        selectedRoute != null
                            ? "Ruta activa • Toca para cambiar"
                            : "Toca para buscar línea o empresa",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: selectedRoute != null
                              ? const Color(0xFF00A859)
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 8),

              if (selectedRoute != null)
                _buildCloseButton()
              else
                _buildFilterButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required Color bgColor,
    required Color iconColor,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onTapDown: (_) => setState(() => _actionPressed = true),
      onTapUp: (_) => setState(() => _actionPressed = false),
      onTapCancel: () => setState(() => _actionPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: bgColor,
          shape: BoxShape.circle,
          boxShadow: _actionPressed
              ? [
                  BoxShadow(
                    color: const Color(0xFF14274E).withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
    );
  }

  Widget _buildCloseButton() {
    return _buildActionButton(
      bgColor: const Color(0xFFFEF2F2),
      iconColor: const Color(0xFFDC2626),
      icon: Icons.close_rounded,
      onTap: () {
        HapticFeedback.mediumImpact();
        ref.read(selectedRouteProvider.notifier).clear();
      },
    );
  }

  Widget _buildFilterButton() {
    return _buildActionButton(
      bgColor: const Color(0xFFF1F5F9),
      iconColor: const Color(0xFF14274E),
      icon: Icons.tune_rounded,
      onTap: () {
        HapticFeedback.lightImpact();
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => const RouteSelectorSheet(),
        );
      },
    );
  }
}
