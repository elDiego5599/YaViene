import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import '../providers/realtime_providers.dart';

class IdleStatusChip extends ConsumerWidget {
  const IdleStatusChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectionState = ref.watch(connectionStateProvider);

    final config = switch (connectionState.valueOrNull) {
      ConnectionStatus.disconnected => (
          dotColor: AppColors.error,
          label: 'Sin conexión al servidor',
          dicho: 'Sin conexión al servidor',
        ),
      ConnectionStatus.reconnecting => (
          dotColor: const Color(0xFFF59E0B),
          label: 'Reconectando...',
          // Los tres puntos son de espera, no de frase: leídos se
          // pronuncian y suenan a que falta algo.
          dicho: 'Reconectando',
        ),
      _ => null,
    };

    if (config == null) return const SizedBox.shrink();

    return Semantics(
      // Esto no se toca: aparece solo, y aparecer es toda su noticia. Sin
      // región viva VoiceOver no dice nada hasta que alguien pasa el dedo
      // por encima, que es justo lo que no va a ocurrir cuando el mapa se
      // queda congelado.
      liveRegion: true,
      label: config.dicho,
      excludeSemantics: true,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: AppColors.divider),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryDeep.withValues(alpha: 0.08),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PulsingDot(color: config.dotColor, size: 9),
            const SizedBox(width: 10),
            Text(
              config.label,
              style: AppTextStyles.etiqueta.copyWith(
                color: AppColors.primaryDeep,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
