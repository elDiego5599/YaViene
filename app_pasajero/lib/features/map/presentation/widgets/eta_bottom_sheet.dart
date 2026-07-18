import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

class EtaBottomSheet extends ConsumerStatefulWidget {
  const EtaBottomSheet({super.key});

  @override
  ConsumerState<EtaBottomSheet> createState() => _EtaBottomSheetState();
}

class _EtaBottomSheetState extends ConsumerState<EtaBottomSheet>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final selectedRoute = ref.watch(selectedRouteProvider);
    final selectedDirection = ref.watch(selectedSentidoProvider);
    final alertActive = ref.watch(proximityAlertProvider);

    if (selectedRoute == null) return const SizedBox.shrink();

    final destination =
        selectedDirection == RouteSentido.ida ? 'Centro' : 'Soledad';

    return AnimatedSize(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      alignment: Alignment.bottomCenter,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.sheet),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.82),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadius.sheet),
              ),
              border: Border(
                top: BorderSide(
                  color: Colors.white.withValues(alpha: 0.5),
                  width: 1.5,
                ),
              ),
              boxShadow: AppShadows.floating,
            ),
            child: SafeArea(
              top: false,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.lg,
                  _isExpanded ? AppSpacing.xl : AppSpacing.lg,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () =>
                          setState(() => _isExpanded = !_isExpanded),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          width: _isExpanded ? 56 : 44,
                          height: 5,
                          decoration: BoxDecoration(
                            color: _isExpanded
                                ? AppColors.primary
                                : AppColors.divider,
                            borderRadius:
                                BorderRadius.circular(AppRadius.pill),
                          ),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.primarySoft,
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                          ),
                          child: const Icon(
                            Icons.directions_bus_rounded,
                            color: AppColors.primaryDeep,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const PulsingDot(color: AppColors.success),
                                  const SizedBox(width: AppSpacing.sm),
                                  Text('Actualizando en tiempo real',
                                      style: AppTextStyles.label),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                destination,
                                style: AppTextStyles.h2,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        AnimatedRotation(
                          turns: _isExpanded ? 0.5 : 0,
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                          child: IconButton(
                            tooltip: _isExpanded ? 'Contraer' : 'Expandir',
                            icon:
                                const Icon(Icons.keyboard_arrow_up_rounded),
                            color: AppColors.textSecondary,
                            onPressed: () => setState(
                                () => _isExpanded = !_isExpanded),
                          ),
                        ),
                      ],
                    ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeOutCubic,
                      height: _isExpanded ? AppSpacing.xl : AppSpacing.lg,
                    ),
                    Center(
                      child: Column(
                        children: [
                          Text('3', style: AppTextStyles.etaNumber),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'minutos para llegar a tu parada',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.body.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_isExpanded) ...[
                      const SizedBox(height: AppSpacing.lg),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: AppColors.backgroundWarm,
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.route_rounded,
                                color: AppColors.primaryDeep),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                selectedRoute.name,
                                style: AppTextStyles.body.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xl),
                    _PremiumAlertButton(
                      isActive: alertActive,
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        final next = !alertActive;
                        ref.read(proximityAlertProvider.notifier).state = next;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                next ? 'Alerta activada' : 'Alerta desactivada'),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PremiumAlertButton extends StatefulWidget {
  final bool isActive;
  final VoidCallback onPressed;

  const _PremiumAlertButton({
    required this.isActive,
    required this.onPressed,
  });

  @override
  State<_PremiumAlertButton> createState() => _PremiumAlertButtonState();
}

class _PremiumAlertButtonState extends State<_PremiumAlertButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final backgroundColor =
        widget.isActive ? AppColors.successLight : AppColors.primaryDeep;
    final foregroundColor = widget.isActive ? AppColors.success : Colors.white;
    final borderColor = widget.isActive
        ? AppColors.success.withValues(alpha: 0.28)
        : AppColors.primaryDeep;

    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        widget.onPressed();
      },
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapCancel: () => setState(() => _isPressed = false),
      onTapUp: (_) => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.975 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(color: borderColor),
            boxShadow: widget.isActive ? null : AppShadows.soft,
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: Row(
              key: ValueKey(widget.isActive),
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  widget.isActive
                      ? Icons.check_circle_rounded
                      : Icons.notifications_none_rounded,
                  color: foregroundColor,
                  size: 21,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  widget.isActive
                      ? 'ALERTA ACTIVADA'
                      : 'AVISARME CUANDO ESTE CERCA',
                  style: AppTextStyles.labelLarge.copyWith(
                    color: foregroundColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
