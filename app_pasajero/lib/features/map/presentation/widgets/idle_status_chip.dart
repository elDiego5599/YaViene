import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

import '../../../../core/providers/red_provider.dart';
import '../../../../core/widgets/pildora_estado.dart';
import '../providers/realtime_providers.dart';

/// Cuánto se queda «Conexión recuperada» antes de irse. Lo bastante para
/// leer dos palabras de reojo; más, y una buena noticia se vuelve ruido.
const kConexionRecuperada = Duration(milliseconds: 2400);

/// El estado de la conexión, en la misma píldora que la ubicación.
///
/// Antes era un punto que latía con «Sin conexión al servidor» al lado, y
/// lo mismo decía con el wifi apagado que con el servidor caído (dueño,
/// 2026-09-30). Ahora distingue las dos cosas —la primera la arregla el
/// pasajero, la segunda no— y avisa también cuando vuelve: sin eso, el
/// aviso se iba sin más y no quedaba claro si los buses eran de ahora.
class IdleStatusChip extends ConsumerStatefulWidget {
  const IdleStatusChip({super.key});

  @override
  ConsumerState<IdleStatusChip> createState() => _IdleStatusChipState();
}

class _IdleStatusChipState extends ConsumerState<IdleStatusChip> {
  /// Hubo un corte de verdad desde la última vez en línea. El primer
  /// «conectado» del arranque no es una recuperación.
  bool _huboCorte = false;

  /// Ya estuvo en línea alguna vez: lo que viene es «Reconectando», no
  /// «Conectando».
  bool _yaConecto = false;
  bool _recuperada = false;
  Timer? _apagar;

  @override
  void dispose() {
    _apagar?.cancel();
    super.dispose();
  }

  void _alConectarse() {
    if (_huboCorte) {
      _apagar?.cancel();
      setState(() => _recuperada = true);
      _apagar = Timer(kConexionRecuperada, () {
        if (mounted) setState(() => _recuperada = false);
      });
    }
    _huboCorte = false;
    _yaConecto = true;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<ConnectionStatus>>(connectionStateProvider,
        (_, ahora) {
      switch (ahora.valueOrNull) {
        case ConnectionStatus.connected:
          _alConectarse();
        case ConnectionStatus.disconnected:
          _huboCorte = true;
        case ConnectionStatus.reconnecting || null:
          break;
      }
    });
    ref.listen<AsyncValue<bool>>(hayRedProvider, (_, ahora) {
      if (ahora.valueOrNull == false) _huboCorte = true;
    });

    final hayRed = ref.watch(hayRedProvider).valueOrNull;
    final conexion = ref.watch(connectionStateProvider).valueOrNull;
    final esperando = _yaConecto ? 'Reconectando' : 'Conectando';

    final PildoraDatos? pildora = switch ((hayRed, conexion)) {
      // Sin red el socket todavía no se ha enterado (espera a que falle su
      // latido), pero el sistema sí: se dice ya, y se dice lo que es.
      (false, _) => const PildoraDatos(
          key: 'sin-red',
          icon: Icons.wifi_off_outlined,
          iconColor: AppColors.warningAccessible,
          tint: AppColors.warningLight,
          text: 'Sin internet',
          sub: 'Los buses vuelven cuando haya señal',
          vivo: true,
        ),
      (_, ConnectionStatus.disconnected) => const PildoraDatos(
          key: 'sin-servidor',
          icon: Icons.cloud_off_outlined,
          iconColor: AppColors.coralAccessible,
          tint: AppColors.coralLight,
          text: 'Sin conexión con el servidor',
          sub: 'Seguimos intentando',
          vivo: true,
        ),
      (_, ConnectionStatus.reconnecting) => PildoraDatos(
          key: 'esperando',
          icon: Icons.sync,
          iconColor: AppColors.primaryAccessible,
          tint: AppColors.primaryTint,
          text: '$esperando…',
          dicho: esperando,
          trabajando: true,
          vivo: true,
        ),
      _ when _recuperada => const PildoraDatos(
          key: 'recuperada',
          icon: Icons.check_circle_outline,
          iconColor: AppColors.primaryAccessible,
          tint: AppColors.primaryTint,
          text: 'Conexión recuperada',
          vivo: true,
        ),
      _ => null,
    };

    return AnimatedSwitcher(
      duration: AppMotion.duracion(context, AppMotion.normal),
      switchInCurve: AppMotion.curvaEntrada,
      switchOutCurve: AppMotion.curvaSalida,
      // La misma entrada que la píldora de ubicación, que va justo encima:
      // dos avisos apilados que se mueven distinto se leen como dos apps.
      transitionBuilder: (child, animation) {
        final slide = Tween<Offset>(
          begin: Offset(0, -0.1 * AppMotion.desplazamiento(context)),
          end: Offset.zero,
        ).animate(animation);
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: slide, child: child),
        );
      },
      child: pildora == null
          ? const SizedBox.shrink(key: ValueKey('en-linea'))
          : KeyedSubtree(
              key: ValueKey(pildora.key),
              child: PildoraEstado(data: pildora),
            ),
    );
  }
}
