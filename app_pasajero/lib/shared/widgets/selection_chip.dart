/// =============================================================================
/// ÁTOMO: SelectionChip
///
/// Chip de selección único. Usado para el selector de sentido (Ida / Vuelta).
/// Diseño: Pill shape, transición animada entre estado activo e inactivo.
/// Touch target: El widget completo responde al tap (mínimo 48dp de altura).
///
/// NO usar emojis. Usar íconos de Material Icons si se necesita un ícono.
///
/// Uso:
/// ```dart
/// SelectionChip(
///   label: 'Ida',
///   icon: Icons.arrow_forward,
///   isSelected: sentido == RouteSentido.ida,
///   onTap: () => ref.read(selectedSentidoProvider.notifier).state = RouteSentido.ida,
/// )
/// ```
/// =============================================================================

import 'package:flutter/material.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

class SelectionChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final IconData? icon;

  const SelectionChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque, // Área de tap completa
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        constraints: const BoxConstraints(minHeight: 44, minWidth: 80),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm + 2,
        ),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.divider,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  icon,
                  key: ValueKey(isSelected),
                  size: 16,
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: AppSpacing.xs + 2),
            ],
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: AppTextStyles.label.copyWith(
                color: isSelected ? Colors.white : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}
