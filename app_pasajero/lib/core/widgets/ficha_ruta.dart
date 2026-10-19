import 'package:flutter/material.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

import '../utils/color_ruta.dart';

/// El radio de la ficha, como fracción del lado: el 22 % de los íconos de
/// app, para que no parezca un botón.
const double radioFicha = 0.22;

/// La letra del código, como fracción del lado: a 0,4 tres caracteres (B18)
/// caben con aire, y uno o dos se quedan en ese tamaño para que todas las
/// fichas se lean igual.
const double letraFicha = 0.4;

/// La ficha de la ruta: un cuadro del color de la ruta (`colorRuta`) con
/// el código en blanco, a 5:1 o más. La misma que lleva el aviso de ícono
/// (`fichaRuta`), en la tarjeta de Avisos en vez del bus (dueño,
/// 2026-10-19).
class FichaRuta extends StatelessWidget {
  const FichaRuta(this.codigo, {super.key, this.lado = 44});

  final String codigo;
  final double lado;

  @override
  Widget build(BuildContext context) => Container(
        width: lado,
        height: lado,
        padding: EdgeInsets.symmetric(horizontal: lado * 0.06),
        decoration: BoxDecoration(
          color: colorRuta(codigo),
          borderRadius: BorderRadius.circular(lado * radioFicha),
        ),
        // Con el texto del sistema grande el código se encoge para caber:
        // la ficha es un ícono de tamaño fijo y el nombre al lado sí crece.
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            codigo,
            maxLines: 1,
            style: AppTextStyles.marca
                .copyWith(fontSize: lado * letraFicha, color: Colors.white),
          ),
        ),
      );
}
