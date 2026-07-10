import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import '../../../../shared/widgets/primary_button.dart';

class EtaBottomSheet extends ConsumerWidget {
  const EtaBottomSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedRoute = ref.watch(selectedRouteProvider);
    final selectedDirection = ref.watch(selectedSentidoProvider);
    final alertActive = ref.watch(proximityAlertProvider);

    if (selectedRoute == null) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
        boxShadow: AppShadows.floating,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: const Icon(Icons.directions_bus_rounded, color: AppColors.primary),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bus hacia',
                          style: AppTextStyles.label,
                        ),
                        Text(
                          selectedDirection == RouteSentido.ida
                              ? 'Centro'
                              : 'Soledad',
                          style: AppTextStyles.h2,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xxl),
              Center(
                child: Column(
                  children: [
                    Text(
                      '3',
                      style: AppTextStyles.etaNumber,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'minutos para llegar a tu parada',
                      style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              if (!alertActive)
                PrimaryButton(
                  label: 'AVISARME CUANDO ESTÉ CERCA',
                  icon: Icons.notifications_none_rounded,
                  onPressed: () {
                    ref.read(proximityAlertProvider.notifier).state = true;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Alerta activada')),
                    );
                  },
                )
              else
                _AlertActiveBanner(),
            ],
          ),
        ),
      ),
    );
  }
}

class _AlertActiveBanner extends StatelessWidget {
  const _AlertActiveBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md, horizontal: AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.successLight,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.success.withOpacity(0.3)),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_rounded, color: AppColors.success),
          SizedBox(width: AppSpacing.md),
          Text(
            'Te avisaremos cuando el bus esté cerca',
            style: TextStyle(color: AppColors.success),
          ),
        ],
      ),
    );
  }
}