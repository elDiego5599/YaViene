import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// La fila de rutas de Flota, que Reportes repite igual (dueño, 2026-10-27:
/// «igual que la flota»): 42 de alto con 9 abajo para la barra de
/// desplazamiento, y la rueda del ratón la mueve de lado.
class TiraPildoras extends StatefulWidget {
  const TiraPildoras({super.key, required this.children});

  final List<Widget> children;

  @override
  State<TiraPildoras> createState() => _TiraPildorasState();
}

class _TiraPildorasState extends State<TiraPildoras> {
  final _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerSignal: (event) {
      if (event is PointerScrollEvent && _controller.hasClients) {
        final next = (_controller.offset + event.scrollDelta.dy).clamp(
          0.0,
          _controller.position.maxScrollExtent,
        );
        if (next != _controller.offset) {
          _controller.jumpTo(next);
        }
      }
    },
    child: Scrollbar(
      controller: _controller,
      interactive: true,
      thumbVisibility: false,
      thickness: 4,
      radius: const Radius.circular(AppRadius.pill),
      child: SizedBox(
        height: 42,
        child: ListView(
          controller: _controller,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.only(bottom: 9),
          children: [
            for (final hijo in widget.children)
              Padding(padding: const EdgeInsets.only(left: 8), child: hijo),
          ],
        ),
      ),
    ),
  );
}

class PildoraRuta extends StatelessWidget {
  const PildoraRuta({
    super.key,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // La ruta elegida en la cápsula azul de Flota y Reportes, con la letra
    // blanca (7,1:1; dueño, 2026-10-27).
    return Semantics(
      button: true,
      selected: active,
      child: Material(
        color: active ? AppColors.capsula : AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(
                color: active ? AppColors.capsula : AppColors.borderStrong,
              ),
            ),
            child: Text(
              label,
              style: AppType.ui(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: active ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
