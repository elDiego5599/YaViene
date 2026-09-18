import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../legal/legal_acceptance.dart';

const _kOnboardingSeen = 'onboarding_seen';

Future<bool> isOnboardingSeen() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_kOnboardingSeen) ?? false;
}

Future<void> markOnboardingSeen() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_kOnboardingSeen, true);
}

/// Dónde abre la app: el mapa solo cuando la bienvenida ya se vio Y los dos
/// documentos están aceptados en su versión de hoy.
///
/// Las dos condiciones son distintas a propósito. Quien instaló la app
/// antes de que hubiera que aceptar nada tiene la primera marca y no la
/// segunda: pasa una vez más por la bienvenida, acepta y no vuelve a
/// verla. Lo mismo el día que los documentos cambien de fondo.
Future<String> rutaDeArranque() async {
  final seen = await isOnboardingSeen();
  final accepted = await isLegalAccepted();
  return seen && accepted ? '/map' : '/onboarding';
}

/// Tras el arranque: si es la primera vez en el dispositivo —o si todavía
/// falta aceptar los documentos— se muestra la pantalla de bienvenida; si
/// no, va directo al mapa.
Future<void> goToHome(BuildContext context) async {
  final ruta = await rutaDeArranque();
  if (!context.mounted) return;
  context.replace(ruta);
}
