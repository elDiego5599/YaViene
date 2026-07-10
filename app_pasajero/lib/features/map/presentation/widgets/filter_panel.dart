import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import '../../../../shared/widgets/selection_chip.dart';
import '../../../../shared/widgets/institutional_dropdown.dart' show InstitutionalDropDown;

class FilterPanel extends ConsumerWidget {
  const FilterPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final companiesAsync = ref.watch(companiesProvider);
    final selectedCompany = ref.watch(selectedCompanyProvider);
    final routesAsync = ref.watch(routesByCompanyProvider(selectedCompany?.id ?? ''));
    final selectedRoute = ref.watch(selectedRouteProvider);
    final selectedDirection = ref.watch(selectedSentidoProvider);

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.card),
            boxShadow: AppShadows.floating,
          ),
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              companiesAsync.when(
                data: (companies) => InstitutionalDropDown<Company>(
                  label: 'Empresa',
                  hint: 'Selecciona una empresa',
                  icon: Icons.business,
                  items: companies,
                  selectedItem: selectedCompany,
                  itemLabel: (c) => c.name,
                  onChanged: (c) {
                    ref.read(selectedCompanyProvider.notifier).state = c;
                    ref.read(selectedRouteProvider.notifier).state = null;
                  },
                ),
                loading: () => const LinearProgressIndicator(color: AppColors.primaryLight),
                error: (_, __) => const Text('Error al cargar empresas'),
              ),
              const SizedBox(height: AppSpacing.sm),
              routesAsync.when(
                data: (routes) => InstitutionalDropDown<RouteInfo>(
                  label: 'Ruta',
                  hint: 'Selecciona una ruta',
                  icon: Icons.route_outlined,
                  items: routes,
                  selectedItem: selectedRoute,
                  itemLabel: (r) => r.name,
                  onChanged: (r) => ref.read(selectedRouteProvider.notifier).state = r,
                ),
                loading: () => const LinearProgressIndicator(color: AppColors.primaryLight),
                error: (_, __) => const SizedBox.shrink(),
              ),
              const SizedBox(height: AppSpacing.md),
              if (selectedRoute != null)
                Row(
                  children: [
                    Expanded(
                      child: SelectionChip(
                        label: 'Ida',
                        icon: Icons.arrow_forward_rounded,
                        isSelected: selectedDirection == RouteSentido.ida,
                        onTap: () => ref.read(selectedSentidoProvider.notifier).state = RouteSentido.ida,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: SelectionChip(
                        label: 'Vuelta',
                        icon: Icons.arrow_back_rounded,
                        isSelected: selectedDirection == RouteSentido.vuelta,
                        onTap: () => ref.read(selectedSentidoProvider.notifier).state = RouteSentido.vuelta,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}