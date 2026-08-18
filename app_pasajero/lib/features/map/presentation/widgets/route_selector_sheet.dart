import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import '../providers/map_guide_copy.dart';
import '../providers/map_tour_provider.dart';
import 'map_tour_overlay.dart';

class RouteSelectorSheet extends ConsumerWidget {
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final companiesAsync = ref.watch(companiesProvider);
    final selectedCompany = ref.watch(selectedCompanyProvider);
    final selectedRoute = ref.watch(selectedRouteProvider);

    return _RouteGuideHost(
      companyGuideKey: companyGuideKey,
      companyChoiceGuideKey: companyChoiceGuideKey,
      routeGuideKey: routeGuideKey,
      routeChoiceGuideKey: routeChoiceGuideKey,
      launchBusesGuideKey: launchBusesGuideKey,
      child: Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              Center(
                child: Container(
                  width: 48,
                  height: 6,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text(
                      'Elige tu ruta',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE6F7F0),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.bolt_rounded, size: 14, color: Color(0xFF00A859)),
                        SizedBox(width: 4),
                        Text(
                          'Tiempo real',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF00A859),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              const Text(
                'EMPRESA',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF64748B),
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 12),
              companiesAsync.when(
                data: (companies) => _PremiumSelectorTile(
                  key: companyGuideKey,
                  title: selectedCompany?.name ?? 'Selecciona una empresa',
                  subtitle: selectedCompany != null ? 'Empresa de transporte masivo' : null,
                  icon: Icons.business_rounded,
                  isActive: selectedCompany != null,
                  onTap: () => _showCompanySelector(context, ref, companies),
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => Column(
                  children: [
                    const Text('Error al cargar empresas'),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () =>
                          ref.invalidate(companiesProvider),
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              const Text(
                'RUTA',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF64748B),
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 12),
              if (selectedCompany == null)
                _PremiumSelectorTile(
                  key: routeGuideKey,
                  title: selectedRoute?.name ?? 'Selecciona una ruta',
                  subtitle: _routeSubtitle(selectedRoute),
                  icon: Icons.alt_route_rounded,
                  isActive: selectedRoute != null,
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Primero selecciona una empresa'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                )
              else
                _RoutesTile(
                  selectedCompanyId: selectedCompany.id,
                  selectedRoute: selectedRoute,
                  routeGuideKey: routeGuideKey,
                  routeChoiceGuideKey: routeChoiceGuideKey,
                ),

              const SizedBox(height: 32),

              ElevatedButton(
                key: launchBusesGuideKey,
                onPressed: selectedRoute != null
                    ? () async {
                        HapticFeedback.mediumImpact();
                        final started = await triggerDemoBuses(
                          selectedCompany?.id ?? '',
                          selectedRoute.id,
                        );
                        if (!context.mounted) return;
                        if (!started) {
                          // Sin confirmación del backend la hoja no se cierra
                          // aparentando éxito: se queda para reintentar.
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'No pudimos iniciar los buses demo · Reintentar'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                          return;
                        }
                        await ref
                            .read(mapGuideProvider.notifier)
                            .complete(MapGuideStep.launchBuses);
                        Navigator.pop(context);
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF14274E),
                  disabledBackgroundColor: const Color(0xFFE2E8F0),
                  foregroundColor: Colors.white,
                  disabledForegroundColor: const Color(0xFF94A3B8),
                  minimumSize: const Size(double.infinity, 58),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  selectedRoute != null ? 'Ver buses en vivo' : 'Selecciona una ruta para continuar',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    color: selectedRoute != null ? Colors.white : const Color(0xFF94A3B8),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
      ),
    );
  }

  void _showCompanySelector(
      BuildContext context, WidgetRef ref, List<Company> companies) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (_) => _RouteGuideHost(
        companyChoiceGuideKey: companyChoiceGuideKey,
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: companies.isEmpty
                    ? const [
                        Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: 24, vertical: 32),
                          child: Text(
                            'Sin empresas disponibles',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ]
                    : companies.asMap().entries.map((entry) {
                        final index = entry.key;
                        final company = entry.value;
                        return ListTile(
                          key: index == 0 ? companyChoiceGuideKey : null,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 8),
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.business_rounded,
                              color: Color(0xFF14274E),
                              size: 20,
                            ),
                          ),
                          title: Text(
                            company.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.4,
                            ),
                          ),
                          trailing: const Icon(
                              Icons.chevron_right_rounded,
                              color: Color(0xFFCBD5E1)),
                          onTap: () {
                            HapticFeedback.selectionClick();
                            final alreadySelected =
                                ref.read(selectedCompanyProvider)?.id ==
                                    company.id;
                            ref
                                .read(selectedCompanyProvider.notifier)
                                .select(company);
                            if (!alreadySelected) {
                              ref.read(selectedRouteProvider.notifier).clear();
                            }
                            ref
                                .read(mapGuideProvider.notifier)
                                .complete(MapGuideStep.company);
                            Navigator.pop(context);
                          },
                        );
                      }).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RouteGuideHost extends ConsumerStatefulWidget {
  const _RouteGuideHost({
    required this.child,
    this.companyGuideKey,
    this.companyChoiceGuideKey,
    this.routeGuideKey,
    this.routeChoiceGuideKey,
    this.launchBusesGuideKey,
  });

  final Widget child;
  final GlobalKey? companyGuideKey;
  final GlobalKey? companyChoiceGuideKey;
  final GlobalKey? routeGuideKey;
  final GlobalKey? routeChoiceGuideKey;
  final GlobalKey? launchBusesGuideKey;

  @override
  ConsumerState<_RouteGuideHost> createState() => _RouteGuideHostState();
}

class _RouteGuideHostState extends ConsumerState<_RouteGuideHost> {
  final _hostKey = GlobalKey();
  Rect? _target;
  MapGuideStep? _measuredStep;

  @override
  Widget build(BuildContext context) {
    final guide = ref.watch(mapGuideProvider);
    final step = guide.step;
    final targetKey = _targetKey(step);
    if (step == MapGuideStep.company ||
        step == MapGuideStep.route ||
        step == MapGuideStep.launchBuses) {
      _scheduleMeasure(step, targetKey);
    }

    final copy = step == null ? null : mapGuideCopy(step);
    final showOverlay = copy != null &&
        _target != null &&
        _measuredStep == step &&
        targetKey != null;
    final visibleStep = showOverlay && step != null ? step : null;

    return Stack(
      key: _hostKey,
      fit: StackFit.passthrough,
      children: [
        widget.child,
        if (visibleStep != null && copy != null)
          Positioned.fill(
            child: MapGuideOverlay(
              target: _target!,
              title: copy.title,
              message: copy.message,
              icon: copy.icon,
              stepIndex: visibleStep.index,
              stepCount: MapGuideStep.values.length,
              primaryLabel: copy.primaryLabel,
              onPrimary: copy.primaryLabel == null
                  ? null
                  : () => ref
                      .read(mapGuideProvider.notifier)
                      .complete(visibleStep),
              onSkip: () => ref.read(mapGuideProvider.notifier).skip(),
            ),
          ),
      ],
    );
  }

  GlobalKey? _targetKey(MapGuideStep? step) {
    switch (step) {
      case MapGuideStep.company:
        return widget.companyChoiceGuideKey ?? widget.companyGuideKey;
      case MapGuideStep.route:
        return widget.routeChoiceGuideKey ?? widget.routeGuideKey;
      case MapGuideStep.launchBuses:
        return widget.launchBusesGuideKey;
      default:
        return null;
    }
  }

  void _scheduleMeasure(MapGuideStep? step, GlobalKey? targetKey) {
    if (step == null || targetKey == null || _measuredStep == step) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || ref.read(mapGuideProvider).step != step) return;
      final hostBox = _hostKey.currentContext?.findRenderObject() as RenderBox?;
      final targetBox = targetKey.currentContext?.findRenderObject() as RenderBox?;
      if (hostBox == null || targetBox == null || !hostBox.attached || !targetBox.attached) {
        return;
      }
      final global = targetBox.localToGlobal(Offset.zero);
      final local = hostBox.globalToLocal(global);
      final rect = local & targetBox.size;
      if (rect.width <= 0 || rect.height <= 0) return;
      setState(() {
        _target = rect;
        _measuredStep = step;
      });
    });
  }
}

String? _routeSubtitle(RouteInfo? route) {
  if (route == null) return null;
  final a = route.terminalA ?? '';
  final b = route.terminalB ?? '';
  if (a.isEmpty && b.isEmpty) return null;
  return '$a ↔ $b';
}

/// Tile de "RUTA": solo se consulta al servidor cuando hay empresa
/// seleccionada (evita la petición espuria con id vacío).
class _RoutesTile extends ConsumerWidget {
  final String selectedCompanyId;
  final RouteInfo? selectedRoute;
  final GlobalKey? routeGuideKey;
  final GlobalKey? routeChoiceGuideKey;

  const _RoutesTile({
    required this.selectedCompanyId,
    required this.selectedRoute,
    this.routeGuideKey,
    this.routeChoiceGuideKey,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routesAsync = ref.watch(routesByCompanyProvider(selectedCompanyId));
    return routesAsync.when(
      data: (routes) => _PremiumSelectorTile(
        key: routeGuideKey,
        title: selectedRoute?.name ?? 'Selecciona una ruta',
        subtitle: _routeSubtitle(selectedRoute),
        icon: Icons.alt_route_rounded,
        isActive: selectedRoute != null,
        onTap: () => _showRouteSelector(
          context,
          ref,
          routes,
          routeChoiceGuideKey: routeChoiceGuideKey,
        ),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => Column(
        children: [
          const Text('Error al cargar las rutas'),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () =>
                ref.invalidate(routesByCompanyProvider(selectedCompanyId)),
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }
}

void _showRouteSelector(
    BuildContext context, WidgetRef ref, List<RouteInfo> routes,
    {GlobalKey? routeChoiceGuideKey}) {
  HapticFeedback.lightImpact();
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
    ),
    builder: (_) => _RouteGuideHost(
      routeChoiceGuideKey: routeChoiceGuideKey,
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
          mainAxisSize: MainAxisSize.min,
          children: routes.isEmpty
              ? const [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                    child: Text(
                      'Esta empresa no tiene rutas aún',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ),
                ]
              : routes.asMap().entries.map((entry) {
                  final index = entry.key;
                  final r = entry.value;
                  return ListTile(
               key: index == 0 ? routeChoiceGuideKey : null,
               contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFE6F7F0),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.alt_route_rounded, color: Color(0xFF00A859), size: 20),
              ),
              title: Text(
                r.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.4,
                ),
              ),
              subtitle: Text(
                _routeSubtitle(r) ?? 'Tiempo real',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF64748B),
                ),
              ),
              trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFFCBD5E1)),
               onTap: () {
                 HapticFeedback.selectionClick();
                 ref.read(selectedRouteProvider.notifier).select(r);
                 ref
                     .read(mapGuideProvider.notifier)
                     .complete(MapGuideStep.route);
                 Navigator.pop(context);
               },
             );
                }).toList(),
            ),
          ),
        ),
      ),
    ),
  );
}

class _PremiumSelectorTile extends StatelessWidget {  final String title;
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
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? const Color(0xFF14274E).withValues(alpha: 0.2) : const Color(0xFFE2E8F0),
            width: isActive ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF14274E).withValues(alpha: 0.04),
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
                color: isActive ? const Color(0xFFE6F7F0) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                color: isActive ? const Color(0xFF00A859) : const Color(0xFF94A3B8),
                size: 22,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                      color: isActive ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF64748B),
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
    );
  }
}
