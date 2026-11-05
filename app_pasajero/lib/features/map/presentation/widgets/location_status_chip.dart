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
    // Con un bus tocado la hoja ya dice a qué distancia viene: la píldora
    // de tu punto y de cuántos buses hay cerca sobra (dueño, 2026-10-19).
    // Sin ubicación se queda, porque dice el problema y su salida.
    final busTocado = ref.watch(selectedBusesProvider).isNotEmpty;

    final PildoraDatos? pill = switch (location.mode) {
      _ when busTocado && location.hasPosition => null,
      UserLocationMode.locating => const PildoraDatos(
          key: 'locating',
          icon: Icons.my_location_outlined,
          iconColor: AppColors.primaryAccessible,
          text: 'Localizando tu ubicación…',
          tint: AppColors.primaryTint,
        ),
      // Sin ubicación, la píldora dice qué pasa y ofrece la salida en una
      // línea. La segunda línea («Toca el mapa para poner tu punto») se
      // fue (dueño, 2026-10-02: «mucho texto»): la hoja de abajo ya lo
      // dice en grande en ese mismo momento —«Toca el mapa donde tomas
      // tu bus», `empty-no-position`—, así que la píldora no es un
      // callejón sin salida aunque el permiso esté bloqueado.
      UserLocationMode.permanentDenied => PildoraDatos(
          key: 'permanentDenied',
          icon: Icons.location_off_outlined,
          iconColor: AppColors.error,
          text: 'Ubicación bloqueada',
          actionLabel: 'Abrir',
          onAction: () => openAppSettings(),
          tint: AppColors.errorLight,
        ),
      UserLocationMode.denied => PildoraDatos(
          key: 'denied',
          icon: Icons.location_disabled_outlined,
          iconColor: AppColors.coralAccessible,
          text: 'Sin ubicación',
          actionLabel: 'Reintentar',
          onAction: () => notifier.useGps(),
          tint: AppColors.coralLight,
        ),
      // El permiso está; lo que falla es el GPS. «Sin señal» lo dice en
      // dos palabras y deja claro que reintentar tiene sentido.
      UserLocationMode.gpsFailed => PildoraDatos(
          key: 'gpsFailed',
          icon: Icons.gps_off_outlined,
          iconColor: AppColors.coralAccessible,
          text: 'GPS sin señal',
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
      // Tras «Quitar»: la hoja de abajo ya dice «Toca el mapa donde tomas
      // tu bus»; la píldora deja el GPS a un toque (dueño, 2026-10-07).
      UserLocationMode.sinPunto => PildoraDatos(
          key: 'sinPunto',
          icon: Icons.add_location_alt_outlined,
          iconColor: AppColors.primaryAccessible,
          text: 'Sin punto de espera',
          actionLabel: 'Usar GPS',
          onAction: () => notifier.useGps(),
          tint: AppColors.primaryTint,
        ),
    };

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
      // Sin píldora, el hueco también cruza: se va con el mismo fundido.
      child: pill == null
          ? const SizedBox.shrink(key: ValueKey('sin-pildora'))
          : KeyedSubtree(
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
      text: _busesCerca(nearbyCount),
      sub: pinHint,
      actionLabel: 'Quitar',
      onAction: () => notifier.clearManualPin(),
      actionDanger: true,
      tint: AppColors.primaryTint,
    );
  }

  PildoraDatos? _gpsPill(UserLocationState location, int? nearbyCount,
      UserLocationNotifier notifier) {
    // «Quitar»: el pin que sigue al GPS sale del mapa para que el usuario
    // toque su punto de espera (dueño, 2026-10-07). Antes era «Fijar», que
    // clavaba el pin donde ya estaba: no se veía hacer nada.
    PildoraDatos conQuitar(PildoraDatos data) => location.hasPosition
        ? PildoraDatos(
            key: '${data.key}-quitar',
            icon: data.icon,
            iconColor: data.iconColor,
            text: data.text,
            tint: data.tint,
            actionLabel: 'Quitar',
            onAction: () => notifier.clearManualPin(),
            actionDanger: true,
          )
        : data;
    if (nearbyCount == null) {
      return conQuitar(const PildoraDatos(
        key: 'gps',
        icon: Icons.my_location_outlined,
        iconColor: AppColors.primaryAccessible,
        text: 'Usando tu ubicación',
        tint: AppColors.primaryTint,
      ));
    }
    if (nearbyCount == 0) {
      return conQuitar(const PildoraDatos(
        key: 'gps-empty',
        icon: Icons.directions_bus_outlined,
        iconColor: AppColors.warningAccessible,
        text: 'No hay buses cerca de ti',
        tint: AppColors.warningLight,
      ));
    }
    return conQuitar(PildoraDatos(
      key: 'gps-near',
      icon: Icons.my_location_outlined,
      iconColor: AppColors.primaryAccessible,
      // El mismo texto que con el pin (dueño, 2026-10-26: «que no varíe
      // sin importar si usa GPS o pin»): el ícono ya dice que es el GPS.
      text: _busesCerca(nearbyCount),
      tint: AppColors.primaryTint,
    ));
  }
}

/// «n buses cerca de tu punto», igual con el GPS que con el pin.
String _busesCerca(int n) => '$n bus${n == 1 ? '' : 'es'} cerca de tu punto';
