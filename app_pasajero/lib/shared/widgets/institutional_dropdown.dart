/// =============================================================================
/// ÁTOMO: InstitutionalDropDown
///
/// Dropdown limpio y accesible para selección de Empresa y Ruta.
/// Maneja 3 estados visuales distintos:
///   1. [loading]: Muestra un shimmer/indicator mientras carga el catálogo.
///   2. [error]: Muestra un mensaje de error con opción de reintentar.
///   3. [data]: Muestra el DropdownButtonFormField normal.
///
/// Touch target: el campo completo tiene mínimo 56dp de altura.
///
/// Uso:
/// ```dart
/// InstitutionalDropDown<Company>(
///   label: 'Empresa',
///   hint: 'Selecciona la empresa',
///   icon: Icons.directions_bus_outlined,
///   items: companies,
///   selectedItem: selectedCompany,
///   itemLabel: (c) => c.name,
///   onChanged: (c) => ref.read(selectedCompanyProvider.notifier).select(c),
///   isLoading: isLoading,
/// )
/// ```
/// =============================================================================

import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class InstitutionalDropDown<T> extends StatelessWidget {
  final String label;
  final String hint;
  final IconData icon;
  final List<T> items;
  final T? selectedItem;
  final String Function(T item) itemLabel;
  final void Function(T item) onChanged;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback? onRetry;

  const InstitutionalDropDown({
    super.key,
    required this.label,
    required this.hint,
    required this.icon,
    required this.items,
    required this.selectedItem,
    required this.itemLabel,
    required this.onChanged,
    this.isLoading = false,
    this.errorMessage,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    // ── Estado: Cargando ───────────────────────────────────────────────────
    if (isLoading) {
      return _FieldSkeleton(label: label, icon: icon);
    }

    // ── Estado: Error ──────────────────────────────────────────────────────
    if (errorMessage != null) {
      return _FieldError(label: label, message: errorMessage!, onRetry: onRetry);
    }

    // ── Estado: Datos disponibles ──────────────────────────────────────────
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: AppTextStyles.label.copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: AppSpacing.xs),
        DropdownButtonFormField<T>(
          value: selectedItem,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 22),
          iconEnabledColor: AppColors.textSecondary,
          style: AppTextStyles.body.copyWith(color: AppColors.textPrimary),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 20, color: AppColors.primary),
            hintText: hint,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.sm + 4,
            ),
          ),
          dropdownColor: AppColors.background,
          borderRadius: AppRadius.card,
          items: items.map((item) {
            return DropdownMenuItem<T>(
              value: item,
              child: Text(
                itemLabel(item),
                style: AppTextStyles.body,
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) onChanged(value);
          },
        ),
      ],
    );
  }
}

// ── Skeleton (Cargando) ───────────────────────────────────────────────────────
class _FieldSkeleton extends StatefulWidget {
  final String label;
  final IconData icon;

  const _FieldSkeleton({required this.label, required this.icon});

  @override
  State<_FieldSkeleton> createState() => _FieldSkeletonState();
}

class _FieldSkeletonState extends State<_FieldSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.4, end: 0.9).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(widget.label,
            style: AppTextStyles.label.copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: AppSpacing.xs),
        AnimatedBuilder(
          animation: _animation,
          builder: (_, __) => Opacity(
            opacity: _animation.value,
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: AppRadius.card,
                border: Border.all(color: AppColors.divider),
              ),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Row(
                children: [
                  Icon(widget.icon, size: 20, color: AppColors.textDisabled),
                  const SizedBox(width: AppSpacing.sm),
                  Container(
                    width: 140,
                    height: 14,
                    decoration: BoxDecoration(
                      color: AppColors.divider,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Error ─────────────────────────────────────────────────────────────────────
class _FieldError extends StatelessWidget {
  final String label;
  final String message;
  final VoidCallback? onRetry;

  const _FieldError({
    required this.label,
    required this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: AppTextStyles.label.copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: AppSpacing.xs),
        Container(
          height: 52,
          decoration: BoxDecoration(
            color: AppColors.error.withOpacity(0.06),
            borderRadius: AppRadius.card,
            border: Border.all(color: AppColors.error.withOpacity(0.4)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Row(
            children: [
              const Icon(Icons.error_outline, size: 18, color: AppColors.error),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(message,
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.error)),
              ),
              if (onRetry != null)
                GestureDetector(
                  onTap: onRetry,
                  child: Text(
                    'Reintentar',
                    style: AppTextStyles.label.copyWith(color: AppColors.primary),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
