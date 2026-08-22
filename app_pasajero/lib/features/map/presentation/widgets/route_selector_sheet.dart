import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import '../../../../core/widgets/map_pattern_painter.dart';
import '../providers/map_guide_copy.dart';
import '../providers/map_tour_provider.dart';
import 'map_tour_overlay.dart';

/// Selector compacto de empresa y ruta, a pantalla completa.
///
/// Ya no es una lista blanca gigante ni abre modales anidados: es una sola
/// carta del mismo tamaño que se alterna entre tres vistas internas
/// (principal, lista de empresas, lista de rutas). Cuando la guía está activa
/// la carta queda debajo del mismo [MapGuideOverlay] del resto de los pasos:
/// scrim oscuro único, solo el objetivo iluminado y la tarjeta flotante.
enum _RouteView { main, companies, routes }

class RouteSelectorSheet extends ConsumerStatefulWidget {
  const RouteSelectorSheet({
    super.key,
    this.companyGuideKey,
    this.companyChoiceGuideKey,
    this.routeGuideKey,
    this.routeChoiceGuideKey,
    this.launchBusesGuideKey,
  });

  final GlobalKey? companyGuideKey;
  final GlobalKey? companyChoiceGuideKey;
  final GlobalKey? routeGuideKey;
  final GlobalKey? routeChoiceGuideKey;
  final GlobalKey? launchBusesGuideKey;

  static Future<void> show(
    BuildContext context, {
    required RouteSelectorSheet sheet,
  }) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Selector de ruta',
      // El framework anima este barrier con fade, nunca con slide.
      barrierColor: const Color(0x66000000),
      transitionDuration: const Duration(milliseconds: 260),
      transitionBuilder: (context, animation, _, child) {
        final curved =
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.06),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
      pageBuilder: (context, _, __) => sheet,
    );
  }

  @override
  ConsumerState<RouteSelectorSheet> createState() => _RouteSelectorSheetState();
}

class _RouteSelectorSheetState extends ConsumerState<RouteSelectorSheet> {
  static const double _fallbackCardHeight = 440;

  final GlobalKey _hostKey = GlobalKey();
  final GlobalKey _mainCardKey = GlobalKey();

  _RouteView _view = _RouteView.main;
  Rect? _target;
  MapGuideStep? _measuredStep;
  GlobalKey? _measuredKey;
  double? _cardHeight;
  bool _everGuided = false;
  bool _measuring = false;

  @override
  Widget build(BuildContext context) {
    final guide = ref.watch(mapGuideProvider);
    final step = guide.step;
    final guided = _isSelectionStep(step);
    _everGuided = _everGuided || guided;
    final targetKey = _targetKeyFor(step, _view);
    if (guided && targetKey != null) _scheduleMeasure(step!, targetKey);
    if (_view == _RouteView.main && _cardHeight == null) _measureMainCard();

    if (_everGuided && !guided) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted &&
            _everGuided &&
            !ref.read(mapGuideProvider).skipped &&
            !_isSelectionStep(ref.read(mapGuideProvider).step)) {
          Navigator.of(context).maybePop();
        }
      });
    }

    final copy = guided && step != null ? mapGuideCopy(step) : null;
    final showOverlay = copy != null &&
        _target != null &&
        _measuredStep == step &&
        _measuredKey == targetKey;

    return Stack(
      key: _hostKey,
      fit: StackFit.expand,
      children: [
        if (!guided) ...[
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).maybePop(),
            ),
          ),
        ],
        _buildCard(context),
        if (showOverlay)
          Positioned.fill(
            child: MapGuideOverlay(
              target: _target!,
              title: copy.title,
              message: copy.message,
              icon: copy.icon,
              stepIndex: mapGuideStepIndex(guide, step!),
              stepCount: mapGuideStepCount(guide),
              primaryLabel: copy.primaryLabel,
              onPrimary: copy.primaryLabel == null
                  ? null
                  : () => ref.read(mapGuideProvider.notifier).complete(step),
              onSkip: () => ref.read(mapGuideProvider.notifier).skip(),
            ),
          ),
      ],
    );
  }

  bool _isSelectionStep(MapGuideStep? step) {
    return step == MapGuideStep.company ||
        step == MapGuideStep.route ||
        step == MapGuideStep.launchBuses;
  }

  GlobalKey? _targetKeyFor(MapGuideStep? step, _RouteView view) {
    switch (view) {
      case _RouteView.companies:
        return widget.companyChoiceGuideKey;
      case _RouteView.routes:
        return widget.routeChoiceGuideKey;
      case _RouteView.main:
        switch (step) {
          case MapGuideStep.company:
            return widget.companyGuideKey;
          case MapGuideStep.route:
            return widget.routeGuideKey;
          case MapGuideStep.launchBuses:
            return widget.launchBusesGuideKey;
          default:
            return null;
        }
    }
  }

  void _scheduleMeasure(MapGuideStep step, GlobalKey targetKey) {
    if (_measuring) return;
    _measuring = true;
    _measureLoop(step, targetKey, 0);
  }

  /// Mide el objetivo de la guía y LO SIGUE mientras se mueve: la carta del
  /// selector anima con `AnimatedSwitcher` (deslizamiento lateral) y
  /// `AnimatedSize` (altura), así que una sola medición quedaría congelada a
  /// medio camino (objetivo "corrido" hacia la derecha). La cadena termina
  /// cuando el rect deja de cambiar (posición estable).
  void _measureLoop(MapGuideStep step, GlobalKey targetKey, int attempt) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measuring = false;
      if (!mounted) return;
      if (ref.read(mapGuideProvider).step != step) return;
      final hostBox = _hostKey.currentContext?.findRenderObject() as RenderBox?;
      final targetBox =
          targetKey.currentContext?.findRenderObject() as RenderBox?;
      if (targetBox == null || !targetBox.attached) {
        if (attempt < 12) _measureLoop(step, targetKey, attempt + 1);
        return;
      }
      if (hostBox == null || !hostBox.attached) return;
      final global = targetBox.localToGlobal(Offset.zero);
      final local = hostBox.globalToLocal(global);
      final rect = local & targetBox.size;
      if (rect.width <= 0 || rect.height <= 0) {
        if (attempt < 12) _measureLoop(step, targetKey, attempt + 1);
        return;
      }
      final changed =
          _target != rect || _measuredStep != step || _measuredKey != targetKey;
      if (changed) {
        setState(() {
          _target = rect;
          _measuredStep = step;
          _measuredKey = targetKey;
        });
        // Sigue midiendo mientras el objetivo se mueve (animación en curso).
        if (attempt < 40) _measureLoop(step, targetKey, attempt + 1);
      }
    });
  }

  void _measureMainCard() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _cardHeight != null || _view != _RouteView.main) return;
      final box = _mainCardKey.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.attached || box.size.height <= 0) return;
      setState(() => _cardHeight = box.size.height);
    });
  }

  Widget _buildCard(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: AnimatedSize(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          alignment: Alignment.bottomCenter,
          child: Material(
            color: Colors.white,
            elevation: 16,
            shadowColor: const Color(0x6614274E),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            clipBehavior: Clip.antiAlias,
            // Mismo patrón de calles del drawer, tenue: identidad propia en
            // la tarjeta que más tiempo mira el usuario.
            child: CustomPaint(
              painter: const MapPatternPainter(color: AppColors.primaryDeep),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) {
                  final slide = Tween<Offset>(
                    begin: const Offset(0.04, 0),
                    end: Offset.zero,
                  ).animate(animation);
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(position: slide, child: child),
                  );
                },
                child: KeyedSubtree(
                  key: ValueKey(_view),
                  child: switch (_view) {
                    _RouteView.main => _buildMainView(context),
                    _RouteView.companies => _buildListView(
                        title: 'Selecciona una empresa',
                        onBack: () => setState(() => _view = _RouteView.main),
                        builder: (_) => _buildCompanyList(context),
                      ),
                    _RouteView.routes => _buildListView(
                        title: 'Selecciona una ruta',
                        onBack: () => setState(() => _view = _RouteView.main),
                        builder: (_) => _buildRouteList(context),
                      ),
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMainView(BuildContext context) {
    final selectedCompany = ref.watch(selectedCompanyProvider);
    final selectedRoute = ref.watch(selectedRouteProvider);
    final companiesAsync = ref.watch(companiesProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        key: _mainCardKey,
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _handle(),
          const SizedBox(height: 24),
          _headerRow(title: 'Elige tu ruta'),
          const SizedBox(height: 24),
          const Text(
            'EMPRESA',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.textSecondary,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 12),
          companiesAsync.when(
            data: (companies) => _PremiumSelectorTile(
              key: widget.companyGuideKey,
              title: selectedCompany?.name ?? 'Selecciona una empresa',
              subtitle: selectedCompany != null
                  ? 'Empresa de transporte masivo'
                  : null,
              icon: Icons.business_rounded,
              isActive: selectedCompany != null,
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() => _view = _RouteView.companies);
              },
            ),
            // La guía ilumina el tile de empresa: mientras carga (o falla) el
            // hueco debe seguir existiendo, si no el overlay desaparece y el
            // usuario podría tocar otro botón y salirse del flujo.
            loading: () => _tilePlaceholder(
              key: widget.companyGuideKey,
              child: const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            ),
            error: (_, __) => _tilePlaceholder(
              key: widget.companyGuideKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Error al cargar empresas',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => ref.invalidate(companiesProvider),
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Reintentar'),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'RUTA',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.textSecondary,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 12),
          _PremiumSelectorTile(
            key: widget.routeGuideKey,
            title: selectedRoute?.name ?? 'Selecciona una ruta',
            subtitle: _routeSubtitle(selectedRoute),
            icon: Icons.alt_route_rounded,
            isActive: selectedRoute != null,
            onTap: () {
              HapticFeedback.lightImpact();
              if (selectedCompany == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Primero selecciona una empresa'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                return;
              }
              setState(() => _view = _RouteView.routes);
            },
          ),
          const SizedBox(height: 32),
          _launchButton(context, selectedCompany, selectedRoute),
        ],
      ),
    );
  }

  Widget _buildListView({
    required String title,
    required VoidCallback onBack,
    required Widget Function(BuildContext) builder,
  }) {
    final height = _cardHeight ?? _fallbackCardHeight;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _handle(),
            const SizedBox(height: 16),
            _headerRow(title: title, onBack: onBack),
            const SizedBox(height: 12),
            Expanded(child: builder(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildCompanyList(BuildContext context) {
    final companiesAsync = ref.watch(companiesProvider);
    final selectedCompany = ref.watch(selectedCompanyProvider);
    return companiesAsync.when(
      data: (companies) => ListView(
        key: widget.companyChoiceGuideKey,
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
          if (companies.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Text(
                'Sin empresas disponibles',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
            )
          else
            ...companies.map((company) {
              return _compactTile(
                icon: Icons.business_rounded,
                iconColor: Colors.white,
                iconBackground: _companyColor(company.id),
                // V2: insignia de iniciales con color determinístico — se
                // reconoce la fila antes de leer el nombre, como en Bolt.
                badgeInitials: _companyInitials(company.name),
                title: company.name,
                subtitle: null,
                selected: selectedCompany?.id == company.id,
                onTap: () {
                  HapticFeedback.selectionClick();
                  final alreadySelected =
                      ref.read(selectedCompanyProvider)?.id == company.id;
                  ref.read(selectedCompanyProvider.notifier).select(company);
                  if (!alreadySelected) {
                    ref.read(selectedRouteProvider.notifier).clear();
                  }
                  ref
                      .read(mapGuideProvider.notifier)
                      .complete(MapGuideStep.company);
                  setState(() => _view = _RouteView.main);
                },
              );
            }),
        ],
      ),
      loading: () => _listPlaceholder(
        key: widget.companyChoiceGuideKey,
      ),
      error: (_, __) => _listPlaceholder(
        key: widget.companyChoiceGuideKey,
        message: 'Error al cargar empresas',
        onRetry: () => ref.invalidate(companiesProvider),
      ),
    );
  }

  Widget _buildRouteList(BuildContext context) {
    final selectedCompany = ref.watch(selectedCompanyProvider);
    if (selectedCompany == null) return const SizedBox.shrink();
    final selectedRoute = ref.watch(selectedRouteProvider);
    final routesAsync = ref.watch(routesByCompanyProvider(selectedCompany.id));
    return routesAsync.when(
      data: (routes) => ListView(
        key: widget.routeChoiceGuideKey,
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
          if (routes.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Text(
                'Esta empresa no tiene rutas aún',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
            )
          else
            ...routes.map((route) => _compactTile(
                  icon: Icons.alt_route_rounded,
                  iconColor: AppColors.primary,
                  iconBackground: AppColors.primaryTint,
                  title: route.name,
                  subtitle: _routeSubtitle(route) ?? 'Tiempo real',
                  selected: selectedRoute?.id == route.id,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    ref.read(selectedRouteProvider.notifier).select(route);
                    ref
                        .read(mapGuideProvider.notifier)
                        .complete(MapGuideStep.route);
                    setState(() => _view = _RouteView.main);
                  },
                )),
        ],
      ),
      loading: () => _listPlaceholder(
        key: widget.routeChoiceGuideKey,
      ),
      error: (_, __) => _listPlaceholder(
        key: widget.routeChoiceGuideKey,
        message: 'Error al cargar las rutas',
        onRetry: () => ref.invalidate(
          routesByCompanyProvider(selectedCompany.id),
        ),
      ),
    );
  }

  Widget _launchButton(
      BuildContext context, Company? company, RouteInfo? route) {
    return ElevatedButton(
      key: widget.launchBusesGuideKey,
      onPressed: route != null
          ? () async {
              HapticFeedback.mediumImpact();
              final messenger = ScaffoldMessenger.of(context);
              final started = await triggerDemoBuses(
                company?.id ?? '',
                route.id,
              );
              if (!context.mounted) return;
              if (!started) {
                Navigator.of(context).maybePop();
                messenger.showSnackBar(
                  SnackBar(
                    content: const Text('No pudimos iniciar los buses demo'),
                    behavior: SnackBarBehavior.floating,
                    action: SnackBarAction(
                      label: 'Reintentar',
                      // La hoja ya se cerró (pop arriba): el reintento no
                      // depende de su context/ref, solo del messenger ya
                      // capturado sobre el Scaffold del mapa.
                      onPressed: () => _retryLaunchBuses(
                        messenger,
                        company?.id ?? '',
                        route.id,
                      ),
                    ),
                  ),
                );
                return;
              }
              await ref
                  .read(mapGuideProvider.notifier)
                  .complete(MapGuideStep.launchBuses);
              if (context.mounted) Navigator.of(context).maybePop();
            }
          : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primaryDeep,
        disabledBackgroundColor: AppColors.divider,
        foregroundColor: Colors.white,
        disabledForegroundColor: AppColors.textDisabled,
        minimumSize: const Size(double.infinity, 58),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        elevation: 0,
      ),
      child: Text(
        route != null
            ? 'Ver buses en vivo'
            : 'Selecciona una ruta para continuar',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
          color: route != null ? Colors.white : AppColors.textDisabled,
        ),
      ),
    );
  }

  Widget _handle() {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: AppColors.divider,
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }

  /// Placeholder del tile de empresa con la MISMA altura que
  /// `_PremiumSelectorTile`: mientras cargan las empresas (o fallan) el hueco
  /// de la guía sigue anclado a su posición real.
  Widget _tilePlaceholder({Key? key, required Widget child}) {
    return Container(
      key: key,
      height: 76,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider),
      ),
      child: child,
    );
  }

  /// Estado de carga/error de las listas secundarias. Mantiene la key del
  /// objetivo de la guía para que el overlay nunca desaparezca mientras el
  /// usuario espera (y no pueda salirse tocando el back u otro botón).
  Widget _listPlaceholder({Key? key, String? message, VoidCallback? onRetry}) {
    return Center(
      key: key,
      child: message == null
          ? const CircularProgressIndicator()
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Reintentar'),
                ),
              ],
            ),
    );
  }

  Widget _headerRow({
    required String title,
    VoidCallback? onBack,
  }) {
    return Row(
      children: [
        if (onBack != null)
          IconButton(
            icon:
                const Icon(Icons.arrow_back_rounded, color: AppColors.primaryDeep),
            onPressed: onBack,
            visualDensity: VisualDensity.compact,
          ),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _compactTile({
    required IconData icon,
    required Color iconColor,
    required Color iconBackground,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
    String? badgeInitials,
    bool selected = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          // F13: la fila ya elegida se marca al volver a la lista, en vez de
          // que todas se vean igual de "sin elegir".
          side: selected
              ? const BorderSide(color: AppColors.primaryDeep, width: 1.5)
              : BorderSide.none,
        ),
        tileColor: const Color(0xFFF8FAFC),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: iconBackground,
            borderRadius: BorderRadius.circular(12),
          ),
          child: badgeInitials != null
              ? Center(
                  child: Text(
                    badgeInitials,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.2,
                    ),
                  ),
                )
              : Icon(icon, color: iconColor, size: 20),
        ),
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            letterSpacing: -0.3,
          ),
        ),
        subtitle: subtitle == null
            ? null
            : Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
        trailing: selected
            ? const Icon(Icons.check_circle_rounded,
                color: AppColors.primaryDeep)
            : const Icon(Icons.chevron_right_rounded,
                color: Color(0xFFCBD5E1)),
        onTap: onTap,
      ),
    );
  }
}

String? _routeSubtitle(RouteInfo? route) {
  if (route == null) return null;
  final a = route.terminalA ?? '';
  final b = route.terminalB ?? '';
  if (a.isEmpty && b.isEmpty) return null;
  return '$a ↔ $b';
}

/// V2: paleta fija tomada de los tokens de marca — el color no se genera al
/// azar, solo se elige de forma determinística según el id de la empresa.
const _companyPalette = [
  AppColors.electricBlue,
  AppColors.coral,
  AppColors.warning,
  AppColors.primaryDeep,
  AppColors.primary,
  AppColors.primaryAccessible,
];

Color _companyColor(String companyId) {
  final hash = companyId.codeUnits.fold<int>(0, (sum, c) => sum + c);
  return _companyPalette[hash % _companyPalette.length];
}

const _companyInitialsStopWords = {'de', 'del', 'la', 'el', 'los', 'las', 'y'};

/// "Transporte del Norte" → "TN": la primera palabra y la siguiente que no
/// sea un conector, igual que el demo de la propuesta.
String _companyInitials(String name) {
  final words =
      name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return '?';
  final significant = words
      .where((w) => !_companyInitialsStopWords.contains(w.toLowerCase()))
      .toList();
  if (significant.isEmpty) return words.first[0].toUpperCase();
  if (significant.length == 1) {
    final w = significant.first;
    return (w.length >= 2 ? w.substring(0, 2) : w).toUpperCase();
  }
  return (significant[0][0] + significant[1][0]).toUpperCase();
}

/// F5: reintento real de "Ver buses en vivo" cuando falla. Vive fuera del
/// State porque la hoja que lo disparó ya se cerró para cuando el usuario
/// toca la acción del SnackBar.
Future<void> _retryLaunchBuses(
  ScaffoldMessengerState messenger,
  String companyId,
  String routeId,
) async {
  final started = await triggerDemoBuses(companyId, routeId);
  if (started) {
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Buses en camino'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    return;
  }
  messenger.showSnackBar(
    SnackBar(
      content: const Text('No pudimos iniciar los buses demo'),
      behavior: SnackBarBehavior.floating,
      action: SnackBarAction(
        label: 'Reintentar',
        onPressed: () => _retryLaunchBuses(messenger, companyId, routeId),
      ),
    ),
  );
}

class _PremiumSelectorTile extends StatefulWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final bool isActive;
  final VoidCallback? onTap;

  const _PremiumSelectorTile({
    super.key,
    required this.title,
    this.subtitle,
    required this.icon,
    required this.isActive,
    this.onTap,
  });

  @override
  State<_PremiumSelectorTile> createState() => _PremiumSelectorTileState();
}

class _PremiumSelectorTileState extends State<_PremiumSelectorTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isActive = widget.isActive;
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.975 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isActive
                  ? AppColors.primaryDeep.withValues(alpha: 0.2)
                  : AppColors.divider,
              width: isActive ? 1.5 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryDeep.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isActive
                      ? AppColors.primaryTint
                      : AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  widget.icon,
                  color: isActive
                      ? AppColors.primary
                      : AppColors.textDisabled,
                  size: 22,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                        color: isActive
                            ? AppColors.textPrimary
                            : AppColors.textDisabled,
                      ),
                    ),
                    if (widget.subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        widget.subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFFCBD5E1)),
            ],
          ),
        ),
      ),
    );
  }
}
