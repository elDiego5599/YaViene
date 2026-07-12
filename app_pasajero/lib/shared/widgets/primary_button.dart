/// =============================================================================
/// ÁTOMO: PrimaryButton
///
/// Botón principal de la aplicación. Estilo institucional: limpio, sólido,
/// sin gradientes ni sombras dramáticas. Touch target mínimo: 52dp.
///
/// Uso:
/// ```dart
/// PrimaryButton(
///   label: 'Activar alerta',
///   onPressed: () => ...,
/// )
/// PrimaryButton(
///   label: 'Cargando...',
///   isLoading: true,
///   onPressed: null,
/// )
/// ```
/// =============================================================================

library;

import 'package:flutter/material.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  /// [isDestructive]: Si es true, usa el color de error en lugar del primario.
  final bool isDestructive;

  /// [icon]: Ícono opcional a la izquierda del label (Material Icons).
  final IconData? icon;

  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.isDestructive = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final backgroundColor = isDestructive ? AppColors.error : AppColors.primary;
    final isDisabled = onPressed == null || isLoading;

    return SizedBox(
      width: double.infinity,
      height: 52, // Touch target WCAG: mínimo 48dp
      child: ElevatedButton(
        onPressed: isDisabled ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor:
              isDisabled ? AppColors.textDisabled : backgroundColor,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg)),
          padding: EdgeInsets.zero,
        ),
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 20),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  Text(label, style: AppTextStyles.labelLarge),
                ],
              ),
      ),
    );
  }
}
