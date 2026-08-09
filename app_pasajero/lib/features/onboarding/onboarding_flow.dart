import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kOnboardingSeen = 'onboarding_seen';

Future<bool> isOnboardingSeen() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_kOnboardingSeen) ?? false;
}

Future<void> markOnboardingSeen() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_kOnboardingSeen, true);
}

/// Tras iniciar sesión (o reentrar con sesión guardada): si es la primera
/// vez en el dispositivo se muestra la pantalla de bienvenida con la
/// explicación de la ubicación; si ya se vio, va directo al mapa.
Future<void> goToHome(BuildContext context) async {
  final seen = await isOnboardingSeen();
  if (!context.mounted) return;
  context.replace(seen ? '/map' : '/onboarding');
}
