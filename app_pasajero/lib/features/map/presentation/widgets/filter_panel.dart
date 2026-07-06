/// =============================================================================
/// WIDGET: FilterPanel
///
/// Panel superpuesto sobre el mapa que contiene los filtros de:
///   - Empresa (InstitutionalDropDown)
///   - Ruta (InstitutionalDropDown — habilitado solo si hay empresa seleccionada)
///   - Sentido (Ida / Vuelta con SelectionChip)
///
/// Diseño: Fondo blanco con borde inferior sutil. Sombra mínima para
/// separarse visualmente del mapa sin crear profundidad artificial.
/// Cuando el mapa Mapbox real se integre, este panel flotará sobre él
/// de forma limpia gracias a la sombra inferior.
/// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/models/company.dart';
import '../../../../core/models/route_info.dart';
import '../../../../shared/widgets/institutional_dropdown.dart';
import '../../../../shared/widgets/selection_chip.dart';

class FilterPanel extends ConsumerWidget {
  const FilterPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final companiesAsync = ref.watch(companiesProvider);
    final selectedCompany = ref.watch(selectedCompanyProvider);
    final selectedRoute = ref.watch(selectedRouteProvider);
    final sentido = ref.watch(selectedSentidoProvider);

    // Carga rutas solo si hay una empresa seleccionada
    final routesAsync = selectedCompany != null
        ? ref.watch(routesByCompanyProvider(selectedCompany.id))
        : null;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withOpacity(0.07),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.md,
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Selector de Empresa ────────────────────────────────────────
            companiesAsync.when(
              data: (companies) => InstitutionalDropDown<Company>(
                label: 'Empresa',
                hint: 'Selecciona la empresa',
                icon: Icons.business_rounded,
                items: companies,
                selectedItem: selectedCompany,
                itemLabel: (c) => c.name,
                onChanged: (company) {
                  // Al cambiar empresa, resetear ruta seleccionada
                  ref.read(selectedRouteProvider.notifier).clear();
                  ref.read(selectedCompanyProvider.notifier).select(company);
                },
              ),
              loading: () => InstitutionalDropDown<Company>(
                label: 'Empresa',
                hint: '',
                icon: Icons.business_rounded,
                items: const [],
                selectedItem: null,
                itemLabel: (c) => c.name,
                onChanged: (_) {},
                isLoading: true,
              ),
              error: (err, _) => InstitutionalDropDown<Company>(
                label: 'Empresa',
                hint: '',
                icon: Icons.business_rounded,
                items: const [],
                selectedItem: null,
                itemLabel: (c) => c.name,
                onChanged: (_) {},
                errorMessage: 'No se pudieron cargar las empresas',
                onRetry: () => ref.invalidate(companiesProvider),
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            // ── Selector de Ruta (deshabilitado hasta elegir empresa) ──────
            if (selectedCompany == null) ...[
              InstitutionalDropDown<RouteInfo>(
                label: 'Ruta',
                hint: 'Primero selecciona una empresa',
                icon: Icons.route_rounded,
                items: const [],
                selectedItem: null,
                itemLabel: (r) => r.name,
                onChanged: (_) {},
              ),
            ] else if (routesAsync != null) ...[
              routesAsync.when(
                data: (routes) => InstitutionalDropDown<RouteInfo>(
                  label: 'Ruta',
                  hint: 'Selecciona la ruta',
                  icon: Icons.route_rounded,
                  items: routes,
                  selectedItem: selectedRoute,
                  itemLabel: (r) => r.name,
                  onChanged: (route) =>
                      ref.read(selectedRouteProvider.notifier).select(route),
                ),
                loading: () => InstitutionalDropDown<RouteInfo>(
                  label: 'Ruta',
                  hint: '',
                  icon: Icons.route_rounded,
                  items: const [],
                  selectedItem: null,
                  itemLabel: (r) => r.name,
                  onChanged: (_) {},
                  isLoading: true,
                ),
                error: (_, __) => InstitutionalDropDown<RouteInfo>(
                  label: 'Ruta',
                  hint: '',
                  icon: Icons.route_rounded,
                  items: const [],
                  selectedItem: null,
                  itemLabel: (r) => r.name,
                  onChanged: (_) {},
                  errorMessage: 'Error cargando rutas',
                  onRetry: () =>
                      ref.invalidate(routesByCompanyProvider(selectedCompany.id)),
                ),
              ),
            ],

            const SizedBox(height: AppSpacing.md),

            // ── Selector de Sentido (Chips) ────────────────────────────────
            Row(
              children: [
                Text(
                  'Sentido',
                  style: AppTextStyles.label.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                SelectionChip(
                  label: 'Ida',
                  icon: Icons.arrow_forward_rounded,
                  isSelected: sentido == RouteSentido.ida,
                  onTap: () => ref.read(selectedSentidoProvider.notifier).state =
                      RouteSentido.ida,
                ),
                const SizedBox(width: AppSpacing.sm),
                SelectionChip(
                  label: 'Vuelta',
                  icon: Icons.arrow_back_rounded,
                  isSelected: sentido == RouteSentido.vuelta,
                  onTap: () => ref.read(selectedSentidoProvider.notifier).state =
                      RouteSentido.vuelta,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
