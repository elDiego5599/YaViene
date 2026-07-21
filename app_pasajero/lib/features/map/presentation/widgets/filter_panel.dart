import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

class FilterPanel extends ConsumerWidget {
  const FilterPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final companiesAsync = ref.watch(companiesProvider);
    final selectedCompany = ref.watch(selectedCompanyProvider);
    final routesAsync =
        ref.watch(routesByCompanyProvider(selectedCompany?.id ?? ''));
    final selectedRoute = ref.watch(selectedRouteProvider);
    final selectedDirection = ref.watch(selectedSentidoProvider);

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.82),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.6),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF14274E).withValues(alpha: 0.08),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Scaffold.of(context).openDrawer();
                        },
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: Colors.grey.shade200),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              )
                            ],
                          ),
                          child: const Icon(Icons.menu_rounded,
                              color: Color(0xFF14274E), size: 22),
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Text(
                        '¿Qué bus esperas?',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.5,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFF00A859).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'EN VIVO',
                          style: TextStyle(
                            color: Color(0xFF00A859),
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  companiesAsync.when(
                    data: (companies) => InstitutionalDropDown<Company>(
                      label: 'Empresa',
                      hint: 'Selecciona una empresa',
                      icon: Icons.business_rounded,
                      items: companies,
                      selectedItem: selectedCompany,
                      itemLabel: (c) => c.name,
                      onChanged: (c) {
                        ref.read(selectedCompanyProvider.notifier).select(c);
                        ref.read(selectedRouteProvider.notifier).clear();
                      },
                    ),
                    loading: () =>
                        const LinearProgressIndicator(color: AppColors.primarySoft),
                    error: (_, __) => const Text('Error al cargar empresas'),
                  ),
                  const SizedBox(height: 12),
                  routesAsync.when(
                    data: (routes) => InstitutionalDropDown<RouteInfo>(
                      label: 'Ruta',
                      hint: 'Selecciona una ruta',
                      icon: Icons.alt_route_rounded,
                      items: routes,
                      selectedItem: selectedRoute,
                      itemLabel: (r) => r.name,
                      onChanged: (r) =>
                          ref.read(selectedRouteProvider.notifier).select(r),
                    ),
                    loading: () =>
                        const LinearProgressIndicator(color: AppColors.primarySoft),
                    error: (_, __) => const SizedBox.shrink(),
                  ),

                  if (selectedRoute != null) ...[
                    const SizedBox(height: 16),
                    AnimatedSelectionChip<RouteSentido>(
                      selectedValue: selectedDirection,
                      options: const [
                        AnimatedSelectionOption(
                          value: RouteSentido.ida,
                          label: 'Ida',
                          icon: Icons.east_rounded,
                        ),
                        AnimatedSelectionOption(
                          value: RouteSentido.vuelta,
                          label: 'Vuelta',
                          icon: Icons.west_rounded,
                        ),
                      ],
                      onChanged: (direction) {
                        HapticFeedback.selectionClick();
                        ref.read(selectedSentidoProvider.notifier).state =
                            direction;
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
