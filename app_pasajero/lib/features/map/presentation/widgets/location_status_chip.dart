import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import '../../../../core/widgets/pildora_estado.dart';
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

    final PildoraDatos? pill = switch (location.mode) {
      UserLocationMode.locating => const PildoraDatos(
          key: 'locating',
          icon: Icons.my_location_outlined,
          iconColor: AppColors.primaryAccessible,
          text: 'Localizando tu ubicación…',
          tint: AppColors.primaryTint,
        ),
      UserLocationMode.permanentDenied => PildoraDatos(
          key: 'permanentDenied',
          icon: Icons.location_off_outlined,
          iconColor: AppColors.error,
          text: 'Ubicación bloqueada en los Ajustes',
          // Sin esta segunda línea la píldora era un callejón sin salida: el
          // único camino que ofrecía salía de la app. La app mide desde un
          // punto, y ese punto se puede poner a mano sin permiso ninguno.
          sub: 'O toca el mapa para poner tu punto',
          actionLabel: 'Abrir',
          onAction: () => openAppSettings(),
          tint: AppColors.errorLight,
        ),
      UserLocationMode.denied => PildoraDatos(
          key: 'denied',
          icon: Icons.location_disabled_outlined,
          iconColor: AppColors.coralAccessible,
          text: 'Sin ubicación',
          sub: 'Toca el mapa para poner tu punto',
          actionLabel: 'Reintentar',
          onAction: () => notifier.useGps(),
          tint: AppColors.coralLight,
        ),
      UserLocationMode.gpsFailed => PildoraDatos(
          key: 'gpsFailed',
          icon: Icons.gps_off_outlined,
          iconColor: AppColors.coralAccessible,
          text: 'No pudimos obtener tu ubicación',
          sub: 'Toca el mapa para poner tu punto',
          actionLabel: 'Reintentar',
          onAction: () => notifier.useGps(),
          tint: AppColors.coralLight,
        ),
      UserLocationMode.manual => _manualPill(nearbyCount, notifier, pinHint),
      UserLocationMode.gps => _gpsPill(location, nearbyCount, notifier),
      // Estado de arranque: dura lo que tarda en leerse el permiso. Aquí no
      // se dice nada a propósito —una invitación que parpadea medio segundo
      // antes de "Localizando…" se lee como un fallo—, y para que este estado
      // no se quede clavado si algo revienta, `initialize()` acaba siempre en
      // un modo con salida.
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
      child: KeyedSubtree(
          key: ValueKey(pill.key), child: PildoraEstado(data: pill)),
    );
  }

  PildoraDatos? _manualPill(
    int? nearbyCount,
    UserLocationNotifier notifier,
    String? pinHint,
  ) {
    // La pista entra y sale de la píldora, así que forma parte de su
    // identidad: sin esto el AnimatedSwitcher no cruzaría el cambio.
    final sufijo = pinHint == null ? '' : '-hint';
    if (nearbyCount == null) {
      return PildoraDatos(
        key: 'manual$sufijo',
        icon: Icons.location_on_outlined,
        iconColor: AppColors.primaryAccessible,
        text: 'Tu punto de espera',
        sub: pinHint,
        actionLabel: 'Quitar',
        onAction: () => notifier.clearManualPin(),
        actionDanger: true,
        tint: AppColors.primaryTint,
      );
    }
    if (nearbyCount == 0) {
      return PildoraDatos(
        key: 'manual-empty$sufijo',
        icon: Icons.directions_bus_outlined,
        iconColor: AppColors.warningAccessible,
        text: 'No hay buses cerca de tu punto',
        sub: pinHint,
        actionLabel: 'Usar GPS',
        onAction: () => notifier.useGps(),
        tint: AppColors.warningLight,
      );
    }
    return PildoraDatos(
      key: 'manual-near$sufijo',
      icon: Icons.location_on_outlined,
      iconColor: AppColors.primaryAccessible,
      text: '$nearbyCount bus${nearbyCount == 1 ? '' : 'es'} '
          'cerca de tu punto',
      sub: pinHint,
      actionLabel: 'Quitar',
      onAction: () => notifier.clearManualPin(),
      actionDanger: true,
      tint: AppColors.primaryTint,
    );
  }

  PildoraDatos? _gpsPill(UserLocationState location, int? nearbyCount,
      UserLocationNotifier notifier) {
    // "Fijar": deja el pin clavado en la posición actual del GPS (útil cuando
    // el punto exacto de espera no es donde el GPS cree que estás). El pin se
    // puede arrastrar y el modo manual permite "Quitar" para volver al GPS.
    PildoraDatos withFix(PildoraDatos data) => location.hasPosition
        ? PildoraDatos(
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
      return withFix(const PildoraDatos(
        key: 'gps',
        icon: Icons.my_location_outlined,
        iconColor: AppColors.primaryAccessible,
        text: 'Usando tu ubicación',
        tint: AppColors.primaryTint,
      ));
    }
    if (nearbyCount == 0) {
      return withFix(const PildoraDatos(
        key: 'gps-empty',
        icon: Icons.directions_bus_outlined,
        iconColor: AppColors.warningAccessible,
        text: 'No hay buses cerca de ti',
        tint: AppColors.warningLight,
      ));
    }
    return withFix(PildoraDatos(
      key: 'gps-near',
      icon: Icons.my_location_outlined,
      iconColor: AppColors.primaryAccessible,
      text: 'Usando tu ubicación · $nearbyCount '
          'bus${nearbyCount == 1 ? '' : 'es'} cerca',
      tint: AppColors.primaryTint,
    ));
  }
}
