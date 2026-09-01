import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import '../providers/pin_hint_provider.dart';
import '../providers/tracking_providers.dart';
import '../providers/user_location_provider.dart';

/// Píldora flotante que informa el estado de la ubicación y cuántos buses
/// hay cerca del usuario en la ruta seleccionada.
///
/// En modo manual lleva además la única explicación de que el pin se
/// arrastra, hasta que el usuario lo arrastra por primera vez. Antes esa
/// frase solo existía en el estado vacío de la hoja de distancia, o sea
/// aparecía antes de que el pin existiera y desaparecía justo cuando se
/// volvía cierta.
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
    final pinHint =
        ref.watch(pinDragLearnedProvider) ? null : 'Arrástralo para moverlo';

    final _PillData? pill = switch (location.mode) {
      UserLocationMode.locating => const _PillData(
          key: 'locating',
          icon: Icons.my_location_rounded,
          iconColor: AppColors.primary,
          text: 'Localizando tu ubicación…',
          tint: AppColors.primaryTint,
        ),
      UserLocationMode.permanentDenied => _PillData(
          key: 'permanentDenied',
          icon: Icons.location_off_rounded,
          iconColor: AppColors.error,
          text: 'Ubicación bloqueada en los Ajustes',
          actionLabel: 'Abrir',
          onAction: () => openAppSettings(),
          tint: AppColors.errorLight,
        ),
      UserLocationMode.denied => _PillData(
          key: 'denied',
          icon: Icons.location_disabled_rounded,
          iconColor: AppColors.coral,
          text: 'Sin ubicación: toca el mapa o reintenta',
          actionLabel: 'Reintentar',
          onAction: () => notifier.useGps(),
          tint: AppColors.coralLight,
        ),
      UserLocationMode.gpsFailed => _PillData(
          key: 'gpsFailed',
          icon: Icons.gps_off_rounded,
          iconColor: AppColors.coral,
          text: 'No pudimos obtener tu ubicación',
          actionLabel: 'Reintentar',
          onAction: () => notifier.useGps(),
          tint: AppColors.coralLight,
        ),
      UserLocationMode.manual => _manualPill(nearbyCount, notifier, pinHint),
      UserLocationMode.gps => _gpsPill(location, nearbyCount, notifier),
      UserLocationMode.unknown => null,
    };

    if (pill == null) return const SizedBox.shrink();

    return AnimatedSwitcher(
      duration: AppMotion.normal,
      switchInCurve: AppMotion.curvaEntrada,
      switchOutCurve: AppMotion.curvaSalida,
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

  _PillData? _manualPill(
    int? nearbyCount,
    UserLocationNotifier notifier,
    String? pinHint,
  ) {
    // La pista entra y sale de la píldora, así que forma parte de su
    // identidad: sin esto el AnimatedSwitcher no cruzaría el cambio.
    final sufijo = pinHint == null ? '' : '-hint';
    if (nearbyCount == null) {
      return _PillData(
        key: 'manual$sufijo',
        icon: Icons.location_on_rounded,
        iconColor: AppColors.primary,
        text: 'Tu punto de espera',
        sub: pinHint,
        actionLabel: 'Quitar',
        onAction: () => notifier.clearManualPin(),
        actionDanger: true,
        tint: AppColors.primaryTint,
      );
    }
    if (nearbyCount == 0) {
      return _PillData(
        key: 'manual-empty$sufijo',
        icon: Icons.directions_bus_rounded,
        iconColor: AppColors.warning,
        text: 'No hay buses cerca de tu punto',
        sub: pinHint,
        actionLabel: 'Usar GPS',
        onAction: () => notifier.useGps(),
        tint: AppColors.warningLight,
      );
    }
    return _PillData(
      key: 'manual-near$sufijo',
      icon: Icons.location_on_rounded,
      iconColor: AppColors.primary,
      text: '$nearbyCount bus${nearbyCount == 1 ? '' : 'es'} '
          'cerca de tu punto',
      sub: pinHint,
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
        icon: Icons.my_location_rounded,
        iconColor: AppColors.primary,
        text: 'Usando tu ubicación',
        tint: AppColors.primaryTint,
      ));
    }
    if (nearbyCount == 0) {
      return withFix(const _PillData(
        key: 'gps-empty',
        icon: Icons.directions_bus_rounded,
        iconColor: AppColors.warning,
        text: 'No hay buses cerca de ti',
        tint: AppColors.warningLight,
      ));
    }
    return withFix(_PillData(
      key: 'gps-near',
      icon: Icons.my_location_rounded,
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
    this.sub,
    this.actionLabel,
    this.onAction,
    this.actionDanger = false,
  });

  final String key;
  final IconData icon;
  final Color iconColor;
  final String text;

  /// Segunda línea, más pequeña y en gris: enseña, no informa.
  final String? sub;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// La acción solo deshace, no destruye: se pinta en gris en vez de verde.
  ///
  /// Estaba en rojo de error. Quitar el punto de espera no borra nada —se
  /// vuelve al GPS y se puede volver a poner tocando el mapa— y el rojo
  /// prometía una consecuencia que no existe; encima era la única alarma de
  /// la pantalla de inicio. Mismo criterio que la X que quita la ruta activa
  /// en la barra de búsqueda.
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
        borderRadius: BorderRadius.circular(AppRadius.pill),
        onTap: data.onAction,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 380),
          padding: const EdgeInsets.fromLTRB(8, 7, 14, 7),
          // Sombra corta y filo fino: una sombra larga sobre el mapa hace
          // que la píldora flote como una nube; una corta la deja apoyada,
          // que es lo que es.
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(color: AppColors.hairline),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryDeep.withValues(alpha: 0.06),
                blurRadius: 10,
                offset: const Offset(0, 3),
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
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(data.icon, size: 18, color: data.iconColor),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.text,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                      softWrap: true,
                      style: AppTextStyles.cuerpoFuerte,
                    ),
                    if (data.sub != null)
                      Text(
                        data.sub!,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: AppTextStyles.pie,
                      ),
                  ],
                ),
              ),
              if (data.actionLabel != null && data.onAction != null) ...[
                const SizedBox(width: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: data.actionDanger
                        ? AppColors.surfaceMuted
                        // F4: primaryAccessible da 4.5:1 con texto blanco;
                        // primary a secas se queda en ~3.1:1.
                        : AppColors.primaryAccessible,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: data.actionDanger
                        ? Border.all(color: AppColors.hairline)
                        : null,
                  ),
                  child: Text(
                    data.actionLabel!,
                    style: AppTextStyles.etiqueta.copyWith(
                      color: data.actionDanger
                          ? AppColors.textSecondary
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
