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
          iconColor: AppColors.primary,
          text: 'Localizando tu ubicación…',
          tint: AppColors.primaryTint,
        ),
      UserLocationMode.permanentDenied => _PillData(
          key: 'permanentDenied',
          icon: Icons.location_off,
          iconColor: AppColors.error,
          text: 'Ubicación bloqueada en los Ajustes',
          actionLabel: 'Abrir',
          onAction: () => openAppSettings(),
          tint: AppColors.errorLight,
        ),
      UserLocationMode.denied => _PillData(
          key: 'denied',
          icon: Icons.location_disabled,
          iconColor: AppColors.coral,
          text: 'Sin ubicación: toca el mapa o reintenta',
          actionLabel: 'Reintentar',
          onAction: () => notifier.useGps(),
          tint: AppColors.coralLight,
        ),
      UserLocationMode.gpsFailed => _PillData(
          key: 'gpsFailed',
          icon: Icons.gps_off,
          iconColor: AppColors.coral,
          text: 'No pudimos obtener tu ubicación',
          actionLabel: 'Reintentar',
          onAction: () => notifier.useGps(),
          tint: AppColors.coralLight,
        ),
      UserLocationMode.manual => _manualPill(nearbyCount, notifier),
      UserLocationMode.gps => _gpsPill(location, nearbyCount, notifier),
      UserLocationMode.unknown => null,
    };

    if (pill == null) return const SizedBox.shrink();

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 240),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        final slide = Tween<Offset>(
          begin: const Offset(0, -0.1),
          end: Offset.zero,
        ).animate(animation);
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: slide, child: child),
        );
      },
      child: KeyedSubtree(key: ValueKey(pill.key), child: _Pill(data: pill)),
    );
  }

  _PillData? _manualPill(int? nearbyCount, UserLocationNotifier notifier) {
    if (nearbyCount == null) {
      return _PillData(
        key: 'manual',
        icon: Icons.location_on,
        iconColor: AppColors.primary,
        text: 'Con tu ubicación',
        actionLabel: 'Quitar',
        onAction: () => notifier.clearManualPin(),
        actionDanger: true,
        tint: AppColors.primaryTint,
      );
    }
    if (nearbyCount == 0) {
      return _PillData(
        key: 'manual-empty',
        icon: Icons.directions_bus,
        iconColor: AppColors.warning,
        text: 'No hay buses cerca de tu pin',
        actionLabel: 'Usar GPS',
        onAction: () => notifier.useGps(),
        tint: AppColors.warningLight,
      );
    }
    return _PillData(
      key: 'manual-near',
      icon: Icons.location_on,
      iconColor: AppColors.primary,
      text:
          'Con tu ubicación: $nearbyCount bus${nearbyCount == 1 ? '' : 'es'} cerca',
      actionLabel: 'Quitar',
      onAction: () => notifier.clearManualPin(),
      actionDanger: true,
      tint: AppColors.primaryTint,
    );
  }

  _PillData? _gpsPill(UserLocationState location, int? nearbyCount,
      UserLocationNotifier notifier) {
    // "Fijar": deja el pin clavado en la posición actual del GPS (útil cuando
    // el punto exacto de espera no es donde el GPS cree que estás). El pin se
    // puede arrastrar y el modo manual permite "Quitar" para volver al GPS.
    _PillData withFix(_PillData data) => location.hasPosition
        ? _PillData(
            key: '${data.key}-fix',
            icon: data.icon,
            iconColor: data.iconColor,
            text: data.text,
            tint: data.tint,
            actionLabel: 'Fijar',
            onAction: () => notifier.setManualPin(location.lat!, location.lon!),
          )
        : data;
    if (nearbyCount == null) {
      return withFix(const _PillData(
        key: 'gps',
        icon: Icons.my_location,
        iconColor: AppColors.primary,
        text: 'Usando tu ubicación',
        tint: AppColors.primaryTint,
      ));
    }
    if (nearbyCount == 0) {
      return withFix(const _PillData(
        key: 'gps-empty',
        icon: Icons.directions_bus,
        iconColor: AppColors.warning,
        text: 'No hay buses cerca de ti',
        tint: AppColors.warningLight,
      ));
    }
    return withFix(_PillData(
      key: 'gps-near',
      icon: Icons.my_location,
      iconColor: AppColors.primary,
      text:
          'Usando tu ubicación · $nearbyCount bus${nearbyCount == 1 ? '' : 'es'} cerca',
      tint: AppColors.primaryTint,
    ));
  }
}

class _PillData {
  const _PillData({
    required this.key,
    required this.icon,
    required this.iconColor,
    required this.text,
    required this.tint,
    this.actionLabel,
    this.onAction,
    this.actionDanger = false,
  });

  final String key;
  final IconData icon;
  final Color iconColor;
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// La acción es de quitar/eliminar: se pinta en rojo suave en vez de verde.
  final bool actionDanger;
  final Color tint;
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
            border: Border.all(color: AppColors.divider),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryDeep.withValues(alpha: 0.07),
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
                        ? AppColors.errorLight
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
                          ? AppColors.error
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
