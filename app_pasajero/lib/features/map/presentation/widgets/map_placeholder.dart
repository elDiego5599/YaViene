/// =============================================================================
/// WIDGET: MapPlaceholder
///
/// Ocupa el 100% del espacio disponible.
/// Será reemplazado por el widget real de Mapbox en el MVP 1.
/// El placeholder simula visualmente la sensación del mapa para que el
/// diseño del panel de filtros y el BottomSheet puedan validarse ya.
/// =============================================================================

import 'package:flutter/material.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

class MapPlaceholder extends StatelessWidget {
  const MapPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFE8EFF5), // Azul-gris muy claro, similar al fondo de mapas
      child: Stack(
        children: [
          // Cuadrícula sutil que simula los tiles de un mapa
          CustomPaint(
            painter: _GridPainter(),
            size: Size.infinite,
          ),

          // Centro: Ícono y texto indicativo
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.textPrimary.withOpacity(0.08),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.map_outlined,
                    size: 36,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Mapa se integrará en MVP 1',
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Mapbox SDK',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textDisabled,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Painter que dibuja una cuadrícula sutil para simular tiles de mapa.
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFCDD5DF)
      ..strokeWidth = 0.8;

    const double gridSize = 60;

    for (double x = 0; x < size.width; x += gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += gridSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
