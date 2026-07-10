/// =============================================================================
/// PANTALLA PRINCIPAL: MapScreen (MVP 1 — Mapa Real)
///
/// Arquitectura de capas (Stack):
///
///   ┌─────────────────────────────────────────┐
///   │  AppBar: Institucional                  │ ← Siempre visible
///   ├─────────────────────────────────────────┤
///   │ ┌─────────────────────────────────────┐ │
///   │ │ CAPA 3: FilterPanel                 │ │ ← Empresa / Ruta / Sentido
///   │ │ (Panel flotante sobre el mapa)      │ │   Fondo blanco, sombra sutil
///   │ ├─────────────────────────────────────┤ │
///   │ │ CAPA 2: DEBUG Tick Badge            │ │ ← Solo en debug mode
///   │ ├─────────────────────────────────────┤ │
///   │ │ CAPA 1: MapWidget (Mapbox REAL)     │ │ ← Motor nativo Mapbox
///   │ │ - Polilínea de ruta (azul)          │ │   Actualizado internamente
///   │ │ - Paradas fijas (círculos sólidos)  │ │   sin reconstruir widgets
///   │ │ - Paradas informales (halos)        │ │
///   │ │ - Bus en movimiento (ícono rotado)  │ │
///   │ ├─────────────────────────────────────┤ │
///   │ │ CAPA 0: EtaBottomSheet             │ │ ← Panel inferior fijo
///   │ └─────────────────────────────────────┘ │
///   └─────────────────────────────────────────┘
/// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ya_viene_core/ya_viene_core.dart';
import '../widgets/filter_panel.dart';
import '../widgets/map_widget.dart';
import '../widgets/eta_bottom_sheet.dart';

class MapScreen extends ConsumerWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Leer la ruta seleccionada para pasarla al MapWidget.
    // Como MapWidget es un ConsumerStatefulWidget, usamos el ID de la ruta
    // para que didUpdateWidget detecte el cambio y recargue las capas.
    final selectedRoute = ref.watch(selectedRouteProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      // ── AppBar ─────────────────────────────────────────────────────────────
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: _MapAppBar(),
      ),
      body: Stack(
        children: [
          // ── CAPA 1: Mapa Real (Mapbox) ─────────────────────────────────────
          // MapWidget es un View nativo que ocupa toda la pantalla.
          // NO se reconstruye cuando el bus emite nuevas coordenadas.
          Positioned.fill(
            child: MapWidget(
              routeId: selectedRoute?.id,
            ),
          ),

          // ── CAPA 2: Panel de Filtros (Empresa / Ruta / Sentido) ────────────
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: FilterPanel(),
          ),

          // ── CAPA 3: Canario de Rendimiento (solo debug) ────────────────────
          const Positioned(
            top: 8,
            right: 12,
            child: _RealtimeTickDebugBadge(),
          ),

          // ── CAPA 4: ETA Bottom Sheet ───────────────────────────────────────
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
        child: Center(
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: const Icon(
              Icons.directions_bus_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
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
            style: AppTextStyles.label,
          ),
        ],
      ),
      actions: [
        Semantics(
          label: 'Centrar mapa en mi ubicación',
          button: true,
          child: IconButton(
            icon: const Icon(Icons.my_location_rounded),
            onPressed: () {
              // TODO: Implementar centrado de mapa en MVP 1
              // Usar mapboxMap.easeTo() con las coordenadas del pasajero
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
// Muestra el tick del realtimeTickProvider cada segundo.
// VERIFICAR en Flutter DevTools → Rebuild Stats:
//   - SOLO este widget debe aparecer con rebuild count > 0 por tick.
//   - MapWidget, FilterPanel y EtaBottomSheet deben tener rebuild count = 0.
// =============================================================================

class _RealtimeTickDebugBadge extends ConsumerWidget {
  const _RealtimeTickDebugBadge();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tickAsync = ref.watch(realtimeTickProvider);

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
          'WS: $tick',
          style: AppTextStyles.label.copyWith(
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
