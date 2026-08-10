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
        dotColor: const Color(0xFFDC2626),
        label: 'Sin conexión al servidor',
      ),
      ConnectionStatus.reconnecting => (
        dotColor: const Color(0xFFF59E0B),
        label: 'Reconectando...',
      ),
      _ => null,
    };

    if (config == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF14274E).withValues(alpha: 0.08),
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
            style: const TextStyle(
              color: Color(0xFF14274E),
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }
}
