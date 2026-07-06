/// =============================================================================
/// PANTALLA PRINCIPAL: MapScreen
///
/// Arquitectura de capas (Stack):
///
///   ┌─────────────────────────────────────┐
///   │  CAPA 3: AppBar institucional        │ ← Siempre visible
///   ├─────────────────────────────────────┤
///   │  CAPA 2: FilterPanel               │ ← Empresa / Ruta / Sentido
///   │  (superpuesto sobre el mapa)        │   Fondo blanco con borde sutil
///   ├─────────────────────────────────────┤
///   │  CAPA 1: MapPlaceholder            │ ← Fondo gris claro
///   │  (se reemplazará por Mapbox SDK)    │   con ícono centrado
///   ├─────────────────────────────────────┤
///   │  CAPA 0: ETA BottomSheet           │ ← Panel inferior semipermanente
///   │  (ETA + botón de alerta)            │   fijo en la parte baja
///   └─────────────────────────────────────┘
///
/// Cada capa es un widget independiente para facilitar el reemplazo
/// individual sin afectar las demás (ej: reemplazar MapPlaceholder
/// por MapboxMap sin tocar el FilterPanel ni el BottomSheet).
/// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/app_providers.dart';
import '../widgets/filter_panel.dart';
import '../widgets/map_placeholder.dart';
import '../widgets/eta_bottom_sheet.dart';

class MapScreen extends ConsumerWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      // ── AppBar ─────────────────────────────────────────────────────────────
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: _MapAppBar(),
      ),
      body: Stack(
        children: [
          // ── CAPA 1: Mapa (Placeholder — se reemplaza por Mapbox SDK) ───────
          const Positioned.fill(
            child: MapPlaceholder(),
          ),

          // ── CAPA 2: Panel de Filtros (Empresa / Ruta / Sentido) ────────────
          // Posicionado en la parte superior, sobre el mapa.
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: FilterPanel(),
          ),

          // ── CAPA 3: Indicador de ticks en tiempo real (DEBUG) ─────────────
          // Canario de rendimiento: solo muestra que los datos llegan sin
          // redibujar toda la pantalla. Eliminar en producción.
          const Positioned(
            top: 8,
            right: 12,
            child: _RealtimeTickDebugBadge(),
          ),

          // ── CAPA 4: ETA Bottom Sheet ───────────────────────────────────────
          // Anclado al fondo. Semipermanente (no se puede cerrar con swipe).
          const Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: EtaBottomSheet(),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// AppBar Institucional
// =============================================================================

class _MapAppBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.background,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      leading: Padding(
        padding: const EdgeInsets.only(left: AppSpacing.md),
        child: Row(
          children: [
            // Logo institucional (placeholder hasta tener el asset)
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: const Icon(
                Icons.directions_bus_rounded,
                color: AppColors.onPrimary,
                size: 20,
              ),
            ),
          ],
        ),
      ),
      leadingWidth: 56,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Ya Viene',
            style: AppTextStyles.h3.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            'Barranquilla',
            style: AppTextStyles.caption,
          ),
        ],
      ),
      actions: [
        // Botón de centrar mi ubicación
        Semantics(
          label: 'Centrar mapa en mi ubicación',
          button: true,
          child: IconButton(
            icon: const Icon(Icons.my_location_rounded),
            onPressed: () {
              // TODO: Implementar centrado de mapa en MVP 1
            },
            color: AppColors.primary,
            tooltip: 'Mi ubicación',
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
      ],
    );
  }
}

// =============================================================================
// Badge de Debug: Canario de Rendimiento
// Muestra el tick del StreamProvider cada segundo.
// Verificar en Flutter DevTools que SOLO este widget se redibuja.
// =============================================================================

class _RealtimeTickDebugBadge extends ConsumerWidget {
  const _RealtimeTickDebugBadge();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tickAsync = ref.watch(realtimeTickProvider);

    // Solo se muestra en modo debug (assert solo se ejecuta en debug mode)
    bool isDebug = false;
    assert(() {
      isDebug = true;
      return true;
    }());

    if (!isDebug) return const SizedBox.shrink();

    return tickAsync.when(
      data: (tick) => Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: AppColors.success.withOpacity(0.9),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Text(
          'WS TICK: $tick',
          style: AppTextStyles.caption.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
