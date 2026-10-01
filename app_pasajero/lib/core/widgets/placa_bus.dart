import 'package:flutter/material.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

/// La placa del bus, pintada como placa: blanca, letra negra y filo
/// negro, la del servicio público (dueño, 2026-09-30; el porqué del blanco
/// en [AppColors.placa]).
///
/// Nació en la hoja de distancia. Salió de ahí cuando el centro de avisos
/// también la pintó (2026-09-30): la placa que se ve en la hoja y la que se
/// ve en el aviso tienen que ser la misma lámina, o el pasajero coteja dos
/// cosas distintas con el bus que llega.
class PlacaBus extends StatelessWidget {
  const PlacaBus(this.placa, {super.key, this.cajaKey});

  final String placa;

  /// La llave de la lámina misma, para quien necesite medirla o leer su
  /// decoración (la hoja la busca como `hoja-placa`).
  final Key? cajaKey;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: cajaKey,
      // 2×8: la letra de 13 respira lo justo, como en la lámina de verdad,
      // donde los caracteres llenan casi todo el alto.
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.placa,
        borderRadius: BorderRadius.circular(AppRadius.xs),
        // 1,5 y no 1: con 1 el filo se perdía en una pantalla con brillo
        // alto, que es como se usa en la calle, y el filo es lo único que
        // separa la lámina blanca de la tarjeta blanca.
        border: Border.all(color: AppColors.textPrimary, width: 1.5),
      ),
      // `etiqueta` en 700 con 1,5 de espaciado: las letras de placa van
      // separadas y en bloque, no apretadas como un título.
      child: Text(
        placa,
        style: AppTextStyles.etiqueta.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}
