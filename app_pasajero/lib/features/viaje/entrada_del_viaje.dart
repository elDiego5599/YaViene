import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

import '../../core/router/app_router.dart';

/// La puerta al planificador, dentro de la hoja de abajo y solo con el pin
/// puesto (dueño, 2026-11-14: en la columna de píldoras del mapa se
/// amontonaban hasta cuatro cuadros). Sin pin no hay de dónde salir, y la
/// hoja pide primero tocar el mapa.
///
/// Una fila como las de Ajustes del iPhone: ficha tonal, título, frase y
/// chevrón. El filo y el radio son los del medallón de encima, para que se
/// lean como de la misma hoja; sin sombra, porque no flota: está en ella.
class EntradaDelViaje extends StatefulWidget {
  const EntradaDelViaje({super.key});

  @override
  State<EntradaDelViaje> createState() => _EntradaDelViajeState();
}

class _EntradaDelViajeState extends State<EntradaDelViaje> {
  bool _hundida = false;

  void _hundir(bool valor) {
    if (_hundida != valor) setState(() => _hundida = valor);
  }

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Semantics(
        button: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => _hundir(true),
          onTapUp: (_) => _hundir(false),
          onTapCancel: () => _hundir(false),
          onTap: () {
            HapticFeedback.lightImpact();
            context.push(AppRoutes.viaje);
          },
          // Se hunde como el bloque de «Escoge empresa y ruta», con su
          // tiempo y su curva, y el fondo se apaga un tono al tocar.
          child: AnimatedScale(
            scale: _hundida ? 0.975 : 1,
            duration: AppMotion.duracion(context, AppMotion.instante),
            curve: AppMotion.curvaEntrada,
            child: AnimatedContainer(
              duration: AppMotion.duracion(context, AppMotion.instante),
              curve: AppMotion.curvaEntrada,
              // 64 de alto: más que los 44 de toque, y cabe con el texto
              // grande porque crece con su contenido.
              constraints: const BoxConstraints(minHeight: 64),
              padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
              decoration: BoxDecoration(
                color: _hundida ? AppColors.primaryTint : AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: AppColors.hairline),
              ),
              child: Row(
                children: [
                  ExcludeSemantics(
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.primaryTint,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: const Icon(
                        Icons.directions_rounded,
                        color: AppColors.primaryAccessible,
                        size: 22,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('¿A dónde vas?',
                            style: AppTextStyles.cuerpoFuerte),
                        const SizedBox(height: 2),
                        Text(
                          'Te decimos qué buses tomar',
                          style: AppTextStyles.pie
                              .copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const ExcludeSemantics(
                    child: Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.textSecondary,
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
