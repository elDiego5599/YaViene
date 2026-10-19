import 'package:flutter/material.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

/// El título de un grupo de la pantalla, fuera de su tarjeta, como los de
/// Salud del iPhone (dueño, 2026-10-18: «separaciones entre títulos y cosas
/// así para que se vea más prolijo»).
///
/// En `titulo` y en tinta: encabeza un bloque. El aire de arriba (28) es más
/// del doble del de abajo (10), así el título se lee pegado a su grupo y
/// separado del anterior. Es encabezado también para el lector de pantalla.
class TituloSeccion extends StatelessWidget {
  const TituloSeccion(this.texto, {super.key, this.primero = false});

  final String texto;

  /// El primero de la pantalla no tiene grupo arriba del que separarse.
  final bool primero;

  @override
  Widget build(BuildContext context) {
    return Padding(
      // 4 hacia adentro: a ras del texto de las tarjetas, no de su filo.
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xs,
        primero ? 12 : 28,
        AppSpacing.xs,
        10,
      ),
      child: Semantics(
        header: true,
        child: Text(
          texto,
          style: AppTextStyles.titulo.copyWith(color: AppColors.textPrimary),
        ),
      ),
    );
  }
}
