import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import '../providers/tracking_providers.dart';
import '../providers/user_location_provider.dart';

/// Píldora flotante que informa el estado de la ubicación del usuario y el
/// número de buses activos de la flota: GPS activo, permiso negado (invita a
/// tocar el mapa), pin manual puesto, o permiso bloqueado (abre Ajustes).
class LocationStatusChip extends ConsumerWidget {
  const LocationStatusChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = ref.watch(userLocationProvider);
    final fleetAsync = ref.watch(fleetBusesProvider);
    final notifier = ref.read(userLocationProvider.notifier);

    final String? fleetCount;
    if (!fleetAsync.hasValue) {
      fleetCount = null;
    } else if (fleetAsync.value!.isEmpty) {
      fleetCount = 'Ningún bus activo ahora';
    } else {
      final count = fleetAsync.value!.length;
      fleetCount = '$count bus${count == 1 ? '' : 'es'} activo${count == 1 ? '' : 's'}';
    }

    final Widget? pill = switch (location.mode) {
      UserLocationMode.locating => const _Pill(
          icon: SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primary,
            ),
          ),
          text: 'Localizando tu ubicación…',
        ),
      UserLocationMode.permanentDenied => _Pill(
          icon: const Icon(Icons.location_off,
              size: 16, color: AppColors.error),
          text: 'Ubicación bloqueada en los Ajustes',
          actionLabel: 'Abrir',
          onAction: () => openAppSettings(),
        ),
      UserLocationMode.denied => _Pill(
          icon: const Icon(Icons.location_on,
              size: 16, color: AppColors.primary),
          text: 'Toca el mapa para indicar dónde estás',
          actionLabel: 'Usar GPS',
          onAction: () => notifier.useGps(),
        ),
      UserLocationMode.manual => _Pill(
          icon: const Icon(Icons.location_on,
              size: 16, color: AppColors.primary),
          text: 'Pin: ${_formatCoords(location.lat, location.lon)}'
              '${fleetCount != null ? ' · $fleetCount' : ''}',
          actionLabel: 'Quitar',
          onAction: () => notifier.clearManualPin(),
        ),
      UserLocationMode.gps => _Pill(
          icon: const Icon(Icons.my_location,
              size: 16, color: AppColors.success),
          text: fleetCount != null
              ? 'Usando tu ubicación · $fleetCount'
              : 'Usando tu ubicación',
        ),
      UserLocationMode.unknown => null,
    };

    if (pill == null) return const SizedBox.shrink();

    return pill;
  }
}

String _formatCoords(double? lat, double? lon) {
  if (lat == null || lon == null) return '—';
  return '${lat.toStringAsFixed(4)}, ${lon.toStringAsFixed(4)}';
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.icon,
    required this.text,
    this.actionLabel,
    this.onAction,
  });

  final Widget icon;
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        onTap: onAction,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 340),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(color: AppColors.divider),
            boxShadow: AppShadows.soft,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              icon,
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  text,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.label.copyWith(
                    color: AppColors.textPrimary,
                    fontSize: 12.5,
                  ),
                ),
              ),
              if (actionLabel != null) ...[
                const SizedBox(width: 6),
                Text(
                  actionLabel!,
                  style: AppTextStyles.label.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
