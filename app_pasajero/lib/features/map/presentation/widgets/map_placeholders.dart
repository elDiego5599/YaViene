// Placeholders del mapa: lo que se ve mientras carga el estilo.
// Extraído de map_widget.dart para que el arranque sea más legible.
import 'package:flutter/material.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

class MapStylePlaceholder extends StatelessWidget {
  const MapStylePlaceholder({
    super.key,
    required this.layersReady,
    required this.placeholderShown,
    required this.onFadeEnd,
  });

  final bool layersReady;
  final bool placeholderShown;
  final VoidCallback onFadeEnd;

  @override
  Widget build(BuildContext context) {
    final visible = !layersReady && placeholderShown;
    return AnimatedOpacity(
      opacity: visible ? 1 : 0,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOut,
      onEnd: () {
        if (!visible && placeholderShown) onFadeEnd();
      },
      child: placeholderShown
          ? GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {},
              child: const ColoredBox(
                color: AppColors.background,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.directions_bus_rounded,
                        size: 44,
                        color: AppColors.textDisabled,
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Preparando tu mapa…',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}

class MapStyleFailedBanner extends StatelessWidget {
  const MapStyleFailedBanner({
    super.key,
    required this.styleFailed,
    required this.onRetry,
  });

  final bool styleFailed;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (!styleFailed) return const SizedBox.shrink();
    return Positioned(
      top: 16,
      left: 16,
      right: 16,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: AppShadows.floating,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              const Icon(Icons.cloud_off_rounded, color: AppColors.coral),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'No se pudo cargar el mapa',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              TextButton(
                onPressed: onRetry,
                child: const Text(
                  'Reintentar',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
