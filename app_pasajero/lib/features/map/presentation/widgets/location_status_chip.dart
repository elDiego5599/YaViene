import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import '../providers/tracking_providers.dart';
import '../providers/user_location_provider.dart';

/// Píldora flotante de cristal que informa el estado de la ubicación y
/// cuántos buses hay cerca del usuario en la ruta seleccionada.
class LocationStatusChip extends ConsumerWidget {
  const LocationStatusChip({super.key, this.routeId});

  final String? routeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = ref.watch(userLocationProvider);
    final nearbyCount = routeId != null && location.hasPosition
        ? ref.watch(nearbyBusesCountProvider(routeId!))
        : null;
    final notifier = ref.read(userLocationProvider.notifier);

    final _PillData? pill = switch (location.mode) {
      UserLocationMode.locating => const _PillData(
          key: 'locating',
          icon: Icons.my_location,
          text: 'Localizando tu ubicación…',
          tint: Color(0xFFE6F7F0),
          iconColor: AppColors.primary,
        ),
      UserLocationMode.permanentDenied => _PillData(
          key: 'permanentDenied',
          icon: Icons.location_off,
          text: 'Ubicación bloqueada en los Ajustes',
          actionLabel: 'Abrir',
          onAction: () => openAppSettings(),
          tint: const Color(0xFFFEE2E2),
          iconColor: AppColors.error,
        ),
      UserLocationMode.denied => const _PillData(
          key: 'denied',
          icon: Icons.touch_app,
          text: 'Toca el mapa para indicar dónde estás',
          tint: Color(0xFFE6F7F0),
          iconColor: AppColors.primary,
        ),
      UserLocationMode.gpsFailed => _PillData(
          key: 'gpsFailed',
          icon: Icons.gps_off,
          text: 'No pudimos obtener tu ubicación',
          actionLabel: 'Reintentar',
          onAction: () => notifier.useGps(),
          tint: const Color(0xFFFEF3C7),
          iconColor: const Color(0xFFD97706),
        ),
      UserLocationMode.manual => _manualPill(location, nearbyCount, notifier),
      UserLocationMode.gps => _gpsPill(nearbyCount),
      UserLocationMode.unknown => null,
    };

    if (pill == null) return const SizedBox.shrink();

    return _Pill(data: pill);
  }

  _PillData? _manualPill(UserLocationState location, int? nearbyCount, UserLocationNotifier notifier) {
    final coords = '${location.lat!.toStringAsFixed(4)}, ${location.lon!.toStringAsFixed(4)}';
    if (nearbyCount == null) {
      return _PillData(
        key: 'manual',
        icon: Icons.location_on,
        text: 'Pin: $coords',
        actionLabel: 'Quitar',
        onAction: () => notifier.clearManualPin(),
        actionDanger: true,
        tint: const Color(0xFFE6F7F0),
        iconColor: AppColors.primary,
      );
    }
    if (nearbyCount == 0) {
      return _PillData(
        key: 'manual-empty',
        icon: Icons.directions_bus,
        text: 'No hay buses cerca de tu pin',
        actionLabel: 'Usar GPS',
        onAction: () => notifier.useGps(),
        tint: const Color(0xFFFEF3C7),
        iconColor: const Color(0xFFD97706),
      );
    }
    return _PillData(
      key: 'manual-near',
      icon: Icons.location_on,
      text: 'Pin: $coords · $nearbyCount bus${nearbyCount == 1 ? '' : 'es'} cerca',
      actionLabel: 'Quitar',
      onAction: () => notifier.clearManualPin(),
      actionDanger: true,
      tint: const Color(0xFFE6F7F0),
      iconColor: AppColors.primary,
    );
  }

  _PillData? _gpsPill(int? nearbyCount) {
    if (nearbyCount == null) {
      return const _PillData(
        key: 'gps',
        icon: Icons.my_location,
        text: 'Usando tu ubicación',
        tint: Color(0xFFE6F7F0),
        iconColor: AppColors.primary,
      );
    }
    if (nearbyCount == 0) {
      return const _PillData(
        key: 'gps-empty',
        icon: Icons.directions_bus,
        text: 'No hay buses cerca de ti',
        tint: Color(0xFFFEF3C7),
        iconColor: Color(0xFFD97706),
      );
    }
    return _PillData(
      key: 'gps-near',
      icon: Icons.my_location,
      text: 'Usando tu ubicación · $nearbyCount bus${nearbyCount == 1 ? '' : 'es'} cerca',
      tint: const Color(0xFFE6F7F0),
      iconColor: AppColors.primary,
    );
  }
}

class _PillData {
  const _PillData({
    required this.key,
    required this.icon,
    required this.text,
    required this.tint,
    required this.iconColor,
    this.actionLabel,
    this.onAction,
    this.actionDanger = false,
  });

  final String key;
  final IconData icon;
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// La acción es de quitar/eliminar: se pinta en rojo suave en vez de verde.
  final bool actionDanger;
  final Color tint;
  final Color iconColor;
}

class _Pill extends StatelessWidget {
  const _Pill({required this.data});

  final _PillData data;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: data.onAction,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 380),
          padding: const EdgeInsets.fromLTRB(8, 7, 14, 7),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFE9EDF2)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF14274E).withValues(alpha: 0.07),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: data.tint,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(data.icon, size: 18, color: data.iconColor),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  data.text,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.25,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (data.actionLabel != null && data.onAction != null) ...[
                const SizedBox(width: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: data.actionDanger
                        ? const Color(0xFFFEE2E2)
                        : AppColors.primary,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    data.actionLabel!,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                      color: data.actionDanger
                          ? const Color(0xFFDC2626)
                          : Colors.white,
                    ),
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
