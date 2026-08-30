import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import 'route_selector_sheet.dart';

class SearchPillBar extends ConsumerStatefulWidget {
  const SearchPillBar({
    super.key,
    this.pillKey,
    this.searchActionKey,
    this.companyGuideKey,
    this.companyChoiceGuideKey,
    this.routeGuideKey,
    this.routeChoiceGuideKey,
    this.launchBusesGuideKey,
    this.onSearchOpened,
  });

  /// GlobalKey sobre la píldora blanca real: el tour de primer uso la mide
  /// para recortar su hueco exactamente sobre ella.
  final GlobalKey? pillKey;
  final GlobalKey? searchActionKey;
  final GlobalKey? companyGuideKey;
  final GlobalKey? companyChoiceGuideKey;
  final GlobalKey? routeGuideKey;
  final GlobalKey? routeChoiceGuideKey;
  final GlobalKey? launchBusesGuideKey;
  final VoidCallback? onSearchOpened;

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
    _openSelector();
  }

  @override
  Widget build(BuildContext context) {
    final selectedRoute = ref.watch(selectedRouteProvider);

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Container(
          key: widget.pillKey,
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryDeep.withValues(alpha: 0.08),
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
                child: Semantics(
                  button: true,
                  label: 'Abrir menú',
                  child: Tooltip(
                    message: 'Menú',
                    child: AnimatedContainer(
                      duration: AppMotion.instante,
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _menuPressed
                            ? AppColors.surfaceMuted
                            : Colors.transparent,
                      ),
                      child: const Icon(
                        Icons.menu_rounded,
                        color: AppColors.primaryDeep,
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  key: widget.searchActionKey,
                  behavior: HitTestBehavior.opaque,
                  onTap: _onSearchTap,
                  // El bloque de texto queda centrado en la píldora: cada fila
                  // usa MainAxisAlignment.center y Flexible para poder
                  // elidir nombres de ruta largos sin desbordar.
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (selectedRoute != null) ...[
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                            ],
                            Flexible(
                              child: Text(
                                selectedRoute?.name ?? "¿Qué bus esperas?",
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                  letterSpacing: -0.4,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Flexible(
                              child: Text(
                                selectedRoute != null
                                    ? "Ruta activa • Toca para cambiar"
                                    : "Toca para buscar tu ruta",
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  // F4: primaryAccessible sí llega a 4.5:1
                                  // sobre blanco a este tamaño; primary
                                  // a secas se queda en ~3.1:1.
                                  color: selectedRoute != null
                                      ? AppColors.primaryAccessible
                                      : AppColors.textSecondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
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
    required Color iconColor,
    required IconData icon,
    required VoidCallback onTap,
    required String semanticLabel,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onTapDown: (_) => setState(() => _actionPressed = true),
      onTapUp: (_) => setState(() => _actionPressed = false),
      onTapCancel: () => setState(() => _actionPressed = false),
      child: Semantics(
        button: true,
        label: semanticLabel,
        child: Tooltip(
          message: semanticLabel,
          child: AnimatedContainer(
            duration: AppMotion.instante,
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color:
                  _actionPressed ? AppColors.surfaceMuted : Colors.transparent,
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
        ),
      ),
    );
  }

  Widget _buildCloseButton() {
    return _buildActionButton(
      iconColor: AppColors.error,
      icon: Icons.close_rounded,
      semanticLabel: 'Quitar ruta activa',
      onTap: () {
        HapticFeedback.mediumImpact();
        // Quitar la ruta activa deja la elección en blanco: también se limpia
        // la empresa para que la nueva elección empiece desde cero.
        ref.read(selectedRouteProvider.notifier).clear();
        ref.read(selectedCompanyProvider.notifier).clear();
      },
    );
  }

  void _openSelector() {
    widget.onSearchOpened?.call();
    RouteSelectorSheet.show(
      context,
      sheet: RouteSelectorSheet(
        companyGuideKey: widget.companyGuideKey,
        companyChoiceGuideKey: widget.companyChoiceGuideKey,
        routeGuideKey: widget.routeGuideKey,
        routeChoiceGuideKey: widget.routeChoiceGuideKey,
        launchBusesGuideKey: widget.launchBusesGuideKey,
      ),
    );
  }

  Widget _buildFilterButton() {
    return _buildActionButton(
      iconColor: AppColors.primaryDeep,
      icon: Icons.tune_rounded,
      semanticLabel: 'Cambiar ruta',
      onTap: () {
        HapticFeedback.lightImpact();
        _openSelector();
      },
    );
  }
}
