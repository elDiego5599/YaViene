import 'package:flutter/painting.dart';

import 'package:ya_viene_core/ya_viene_core.dart';

/// Los seis colores con los que puede salir una empresa.
///
/// Antes se tomaban prestados de los tokens semánticos, y ahí estaba el
/// problema: el naranja es el de «cuidado» y el coral el de «sin conexión».
/// Una empresa de buses aparecía vestida de aviso, con el mismo color que
/// usa la app para decir que algo va mal. Este es un escalón de azul noche
/// a verde: seis peldaños que se distinguen entre sí sin que ninguno
/// signifique nada más en el resto de la app, y todos lo bastante oscuros
/// para llevar letra blanca encima.
const coloresEmpresa = [
  Color(0xFF14274E), // noche
  Color(0xFF22406F), // marino
  Color(0xFF1C5670), // petróleo
  Color(0xFF0F6A65), // verde azulado
  Color(0xFF1C6B4C), // bosque
  Color(0xFF3B6B2E), // oliva
];

/// El rojito de Coochofal, pedido por el dueño (2026-10-28). Más hondo que
/// el coral del bus en el mapa (#E86A5E) y que `coralAccessible` (#C0392B),
/// para que su ficha no se lea como un bus ni como un aviso: 6,54:1 con
/// letra blanca.
const rojoCoochofal = Color(0xFFB3261E);

/// Las empresas que eligen su color; las demás salen del escalón.
const _coloresPropios = {'EMP-04': rojoCoochofal};

/// El color de la empresa [companyId]: el de su insignia en «Elige
/// empresa» y el de la ficha de sus avisos (dueño, 2026-10-19), para que el
/// aviso se reconozca por su empresa.
Color colorEmpresa(String companyId) {
  final propio = _coloresPropios[companyId];
  if (propio != null) return propio;
  final hash = companyId.codeUnits.fold<int>(0, (sum, c) => sum + c);
  return coloresEmpresa[hash % coloresEmpresa.length];
}

/// El color de la ficha de un aviso: el de su empresa; en un aviso de
/// antes, que no sabe de qué empresa es, el azul de botón de siempre.
Color colorFicha({String? companyId}) =>
    companyId == null ? AppColors.acento : colorEmpresa(companyId);
