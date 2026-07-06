/// =============================================================================
/// WIDGET: EtaBottomSheet
///
/// Panel inferior semipermanente. No puede cerrarse con swipe (es parte
/// integral de la UI de seguimiento, no un panel opcional).
///
/// Contenido:
///   - Handle visual (pastilla decorativa)
///   - Información de ETA: número grande + unidad + descripción
///   - Distancia al bus más cercano
///   - Botón de "Activar alerta de proximidad" (toggle)
///
/// El número de ETA usa [AppTextStyles.etaNumber] (48dp, bold, azul)
/// para ser legible de un vistazo en condiciones de movimiento y luz solar.
///
/// Diseño: Fondo blanco sólido, bordes redondeados arriba, sombra elevada.
/// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../shared/widgets/primary_button.dart';

class EtaBottomSheet extends ConsumerWidget {
  const EtaBottomSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedRoute = ref.watch(selectedRouteProvider);
    final alertActive = ref.watch(proximityAlertProvider);

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: AppRadius.sheet,
        boxShadow: [
          BoxShadow(
            color: Color(0x1A0D0D0D),
            blurRadius: 24,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Handle decorativo ──────────────────────────────────────────────
          const _SheetHandle(),
          const SizedBox(height: AppSpacing.md),

          // ── Contenido del panel ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              AppSpacing.lg,
            ),
            child: selectedRoute == null
                ? const _EmptyState()
                : const _EtaContent(),
          ),

          // SafeArea para el home indicator de iOS
          SizedBox(height: MediaQuery.of(context).padding.bottom > 0 ? 0 : 0),
        ],
      ),
    );
  }
}

// =============================================================================
// Estado Vacío (sin ruta seleccionada)
// =============================================================================

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: const Icon(
            Icons.search_rounded,
            color: AppColors.textDisabled,
            size: 24,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Selecciona una ruta',
              style: AppTextStyles.labelLarge.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              'para ver los buses en tiempo real',
              style: AppTextStyles.body.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// =============================================================================
// Contenido ETA (con ruta seleccionada)
// =============================================================================

class _EtaContent extends ConsumerWidget {
  const _EtaContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertActive = ref.watch(proximityAlertProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Fila: ETA + Distancia ──────────────────────────────────────────
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Número grande de ETA
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Próximo bus',
                  style: AppTextStyles.etaLabel,
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    // NOTA: En MVP 1, este valor vendrá del ETA cacheado
                    // en Redis. Por ahora es un placeholder estático.
                    Text(
                      '7',
                      style: AppTextStyles.etaNumber,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      'min',
                      style: AppTextStyles.h2.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const Spacer(),

            // Distancia al bus
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Distancia', style: AppTextStyles.etaLabel),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '1.2',
                      style: AppTextStyles.h2.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      'km',
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),

        const SizedBox(height: AppSpacing.sm),

        // ── Fila de estado: buses activos ──────────────────────────────────
        _BusStatusRow(),

        const SizedBox(height: AppSpacing.lg),
        const Divider(height: 1),
        const SizedBox(height: AppSpacing.md),

        // ── Botón de Alerta de Proximidad ──────────────────────────────────
        PrimaryButton(
          label: alertActive
              ? 'Alerta de proximidad activa'
              : 'Activar alerta de proximidad',
          icon: alertActive ? Icons.notifications_active_rounded : Icons.notifications_none_rounded,
          onPressed: () {
            ref.read(proximityAlertProvider.notifier).state = !alertActive;
          },
          isDestructive: alertActive, // Rojo cuando está activa (para desactivar)
        ),

        if (alertActive) ...[
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.info_outline_rounded,
                  size: 14, color: AppColors.textSecondary),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'Te avisaremos cuando el bus est\u00e9 a 2 km',
                style: AppTextStyles.caption,
              ),
            ],
          ),
        ],
      ],
    );
  }
}

// =============================================================================
// Fila de Estado de Buses
// =============================================================================

class _BusStatusRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatusBadge(
          count: 3,
          label: 'en ruta',
          color: AppColors.busActive,
          icon: Icons.directions_bus_rounded,
        ),
        const SizedBox(width: AppSpacing.sm),
        _StatusBadge(
          count: 1,
          label: 'sin se\u00f1al',
          color: AppColors.busGhost,
          icon: Icons.signal_wifi_off_rounded,
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final int count;
  final String label;
  final Color color;
  final IconData icon;

  const _StatusBadge({
    required this.count,
    required this.label,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: AppSpacing.xs),
          Text(
            '$count $label',
            style: AppTextStyles.caption.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Handle Decorativo del BottomSheet
// =============================================================================

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Center(
        child: Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: AppColors.divider,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}
