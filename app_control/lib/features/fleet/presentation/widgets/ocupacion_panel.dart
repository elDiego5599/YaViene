import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Pestaña de ocupación de Reportes, lista para el aforo con IA
/// (`YaVieneBackend/prototipo-aforo`): las cámaras del bus dicen si va
/// vacío, medio o lleno. Mientras ningún bus tenga cámara conectada, la
/// pestaña lo dice tal cual y muestra los tres estados que verá la empresa.
class OcupacionPanel extends StatelessWidget {
  const OcupacionPanel({super.key});

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.card),
      border: Border.all(color: AppColors.border),
      boxShadow: AppColors.sombraTarjeta,
    ),
    child: Center(
      child: ConstrainedBox(
        // 520 px: el párrafo cabe en tres líneas de unos 70 caracteres.
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.surfaceRaised,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Icon(
                  Icons.groups_outlined,
                  color: AppColors.navy,
                  size: 24,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Ocupación de tus buses',
                style: AppType.ui(
                  color: AppColors.navy,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Con las cámaras del bus, un modelo de IA dirá cómo va cada '
                'uno, para que tus pasajeros sepan si les conviene esperar el '
                'siguiente.',
                textAlign: TextAlign.center,
                style: AppType.ui(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 22),
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _EstadoAforo(
                    color: AppColors.online,
                    icono: Icons.event_seat_outlined,
                    texto: 'Vacío',
                  ),
                  SizedBox(width: 10),
                  _EstadoAforo(
                    color: AppColors.ghost,
                    icono: Icons.people_outline,
                    texto: 'Medio',
                  ),
                  SizedBox(width: 10),
                  _EstadoAforo(
                    color: AppColors.offline,
                    icono: Icons.groups_outlined,
                    texto: 'Lleno',
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Container(
                key: const ValueKey('ocupacion-sin-camaras'),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceRaised,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.videocam_off_outlined,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Aún no hay buses con cámara de aforo conectada',
                        style: AppType.ui(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Ficha de un estado del aforo: el color va en el ícono y el texto, sobre
/// su mismo tono al 8 %, como la hora pico de Búsquedas. Contraste medido
/// sobre ese fondo: verde 4,9:1, ámbar 4,85:1, rojo 4,83:1 (AA, 4,5:1).
class _EstadoAforo extends StatelessWidget {
  const _EstadoAforo({
    required this.color,
    required this.icono,
    required this.texto,
  });

  final Color color;
  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) => Container(
    width: 96,
    padding: const EdgeInsets.symmetric(vertical: 12),
    decoration: BoxDecoration(
      color: Color.alphaBlend(color.withValues(alpha: 0.08), AppColors.surface),
      borderRadius: BorderRadius.circular(AppRadius.md),
    ),
    child: Column(
      children: [
        Icon(icono, size: 20, color: color),
        const SizedBox(height: 6),
        Text(
          texto,
          style: AppType.ui(
            color: color,
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
}
