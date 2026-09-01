import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import '../providers/map_view_state.dart';
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
  bool _searchPressed = false;

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
            borderRadius: BorderRadius.circular(AppRadius.pill),
            // La píldora flota sobre un mapa de colores impredecibles: el
            // filo la recorta contra un parque verde o una avenida clara,
            // donde solo la sombra la dejaba difusa.
            border: Border.all(color: AppColors.hairline),
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
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: GestureDetector(
                  key: widget.searchActionKey,
                  behavior: HitTestBehavior.opaque,
                  onTap: _onSearchTap,
                  onTapDown: (_) => setState(() => _searchPressed = true),
                  onTapUp: (_) => setState(() => _searchPressed = false),
                  onTapCancel: () => setState(() => _searchPressed = false),
                  // El bloque de texto queda centrado en la píldora: cada fila
                  // usa MainAxisAlignment.center y Flexible para poder
                  // elidir nombres de ruta largos sin desbordar.
                  child: Semantics(
                    button: true,
                    label: selectedRoute != null
                        ? 'Ruta activa: ${selectedRoute.name}. Toca para '
                            'cambiar'
                        : '¿Qué bus esperas? Toca para buscar tu ruta',
                    excludeSemantics: true,
                    // Los dos botones de los lados se apagan al tocarlos y
                    // esta zona —que es la mitad de la píldora— no acusaba
                    // recibo de nada. Un texto sin fondo propio responde
                    // atenuándose, como en iOS.
                    child: AnimatedOpacity(
                      opacity: _searchPressed ? 0.5 : 1,
                      duration: AppMotion.instante,
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
                                    style: AppTextStyles.subtitulo,
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
                                    // F4: primaryAccessible sí llega a
                                    // 4.5:1 sobre blanco a este tamaño;
                                    // primary a secas se queda en ~3.1:1.
                                    style: selectedRoute != null
                                        ? AppTextStyles.pie.copyWith(
                                            color:
                                                AppColors.primaryAccessible,
                                          )
                                        : AppTextStyles.pie,
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
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
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
    bool filled = false,
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
              color: _actionPressed
                  ? AppColors.surfaceMuted
                  : (filled
                      ? AppColors.surfaceMuted.withValues(alpha: 0.7)
                      : Colors.transparent),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
        ),
      ),
    );
  }

  /// Botón de limpiar, no de borrar.
  ///
  /// Estaba en rojo de error. Quitar la ruta elegida no destruye nada —se
  /// vuelve a elegir en dos toques— y el rojo prometía una consecuencia
  /// que no existe. Va en gris con su círculo, como la X que limpia un
  /// campo de texto en iOS.
  Widget _buildCloseButton() {
    return _buildActionButton(
      iconColor: AppColors.textSecondary,
      filled: true,
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

  /// Abre el selector y avisa mientras esté arriba.
  ///
  /// El aviso es lo que aparta la hoja de distancia, que se apoya en el
  /// mismo borde: la bandera se baja cuando el diálogo termina de cerrarse,
  /// haya elegido ruta o no, así que la hoja vuelve sola si el usuario se
  /// arrepintió.
  Future<void> _openSelector() async {
    widget.onSearchOpened?.call();
    ref.read(routeSelectorOpenProvider.notifier).state = true;
    try {
      await RouteSelectorSheet.show(
        context,
        sheet: RouteSelectorSheet(
          companyGuideKey: widget.companyGuideKey,
          companyChoiceGuideKey: widget.companyChoiceGuideKey,
          routeGuideKey: widget.routeGuideKey,
          routeChoiceGuideKey: widget.routeChoiceGuideKey,
          launchBusesGuideKey: widget.launchBusesGuideKey,
        ),
      );
    } finally {
      if (mounted) ref.read(routeSelectorOpenProvider.notifier).state = false;
    }
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
