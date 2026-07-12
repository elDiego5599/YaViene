import 'package:flutter/material.dart';

import '../../ya_viene_core.dart';

class ModernDropDown<T> extends StatefulWidget {
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

  const ModernDropDown({
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
  State<ModernDropDown<T>> createState() => _ModernDropDownState<T>();
}

class _ModernDropDownState<T> extends State<ModernDropDown<T>> {
  late final FocusNode _focusNode;
  bool _isExpanded = false;

  bool get _isActive => _isExpanded || _focusNode.hasFocus;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode()..addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_handleFocusChange)
      ..dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    if (!mounted) return;
    if (!_focusNode.hasFocus && _isExpanded) {
      setState(() => _isExpanded = false);
    } else {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) {
      return _FieldSkeleton(label: widget.label, icon: widget.icon);
    }

    if (widget.errorMessage != null) {
      return _FieldError(
        label: widget.label,
        message: widget.errorMessage!,
        onRetry: widget.onRetry,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 180),
          style: AppTextStyles.label.copyWith(
            color: _isActive ? AppColors.primaryDeep : AppColors.textSecondary,
          ),
          child: Text(widget.label),
        ),
        const SizedBox(height: AppSpacing.xs),
        AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: _isActive ? AppColors.primaryTint : AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: _isActive ? AppColors.primary : AppColors.divider,
              width: _isActive ? 1.4 : 1,
            ),
            boxShadow: _isActive ? AppShadows.soft : null,
          ),
          child: DropdownButtonFormField<T>(
            initialValue: widget.selectedItem,
            focusNode: _focusNode,
            isExpanded: true,
            icon: AnimatedRotation(
              turns: _isExpanded ? 0.5 : 0,
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              child: Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 22,
                color:
                    _isActive ? AppColors.primaryDeep : AppColors.textSecondary,
              ),
            ),
            style: AppTextStyles.body.copyWith(color: AppColors.textPrimary),
            decoration: InputDecoration(
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.sm + 4,
              ),
              prefixIcon: Icon(
                widget.icon,
                size: 20,
                color: _isActive ? AppColors.primaryDeep : AppColors.primary,
              ),
              hintText: widget.hint,
            ),
            dropdownColor: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.card),
            onTap: () => setState(() => _isExpanded = true),
            items: widget.items.map((item) {
              return DropdownMenuItem<T>(
                value: item,
                child: Text(
                  widget.itemLabel(item),
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: (value) {
              setState(() => _isExpanded = false);
              if (value != null) widget.onChanged(value);
            },
          ),
        ),
      ],
    );
  }
}

class InstitutionalDropDown<T> extends ModernDropDown<T> {
  const InstitutionalDropDown({
    super.key,
    required super.label,
    required super.hint,
    required super.icon,
    required super.items,
    required super.selectedItem,
    required super.itemLabel,
    required super.onChanged,
    super.isLoading,
    super.errorMessage,
    super.onRetry,
  });
}

class _FieldSkeleton extends StatefulWidget {
  final String label;
  final IconData icon;

  const _FieldSkeleton({required this.label, required this.icon});

  @override
  State<_FieldSkeleton> createState() => _FieldSkeletonState();
}

class _FieldSkeletonState extends State<_FieldSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _animation = Tween<double>(
      begin: 0.46,
      end: 0.86,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
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
        Text(widget.label, style: AppTextStyles.label),
        const SizedBox(height: AppSpacing.xs),
        AnimatedBuilder(
          animation: _animation,
          builder: (_, __) => Opacity(
            opacity: _animation.value,
            child: Container(
              height: 54,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: AppColors.divider),
              ),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Row(
                children: [
                  Icon(widget.icon, size: 20, color: AppColors.textDisabled),
                  const SizedBox(width: AppSpacing.sm),
                  Container(
                    width: 136,
                    height: 13,
                    decoration: BoxDecoration(
                      color: AppColors.divider,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
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

class _FieldError extends StatelessWidget {
  final String label;
  final String message;
  final VoidCallback? onRetry;

  const _FieldError({required this.label, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: AppTextStyles.label),
        const SizedBox(height: AppSpacing.xs),
        Container(
          constraints: const BoxConstraints(minHeight: 54),
          decoration: BoxDecoration(
            color: AppColors.errorLight,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.error.withValues(alpha: 0.28)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Row(
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 18,
                color: AppColors.error,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  message,
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.error,
                    fontSize: 12,
                  ),
                ),
              ),
              if (onRetry != null)
                TextButton(
                  onPressed: onRetry,
                  child: Text(
                    'Reintentar',
                    style: AppTextStyles.label.copyWith(
                      color: AppColors.primaryDeep,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
