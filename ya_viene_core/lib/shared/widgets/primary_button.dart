import 'package:flutter/material.dart';
import '../../ya_viene_core.dart';

class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isDestructive;
  final IconData? icon;
  final Color? colorOverride;
  final Color? textColorOverride;

  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.isDestructive = false,
    this.icon,
    this.colorOverride,
    this.textColorOverride,
  });

  @override
  Widget build(BuildContext context) {
    final backgroundColor =
        colorOverride ?? (isDestructive ? AppColors.error : AppColors.primary);
    final foregroundColor = textColorOverride ?? Colors.white;
    final isDisabled = onPressed == null || isLoading;

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: isDisabled ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor:
              isDisabled ? AppColors.textDisabled : backgroundColor,
          foregroundColor: foregroundColor,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg)),
          padding: EdgeInsets.zero,
        ),
        child: isLoading
            ? SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(foregroundColor),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 20, color: foregroundColor),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  Text(label,
                      style: AppTextStyles.labelLarge
                          .copyWith(color: foregroundColor)),
                ],
              ),
      ),
    );
  }
}
