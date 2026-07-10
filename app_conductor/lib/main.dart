/// =============================================================================
/// ENTRY POINT — APP CONDUCTOR (MVP 0)
///
/// Diseño de UI puramente utilitario, de alto contraste. Cero Mapas.
/// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

import 'features/tracking/background_service_config.dart';
import 'features/turn/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Forzar vertical
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Inicializar Background Service
  await initializeBackgroundService();

  runApp(
    const ProviderScope(
      child: YaVieneConductorApp(),
    ),
  );
}

class YaVieneConductorApp extends StatelessWidget {
  const YaVieneConductorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ya Viene Conductor',
      debugShowCheckedModeBanner: false,
      // Se reutiliza el tema institucional estricto (Light Mode, Inter)
      // desde el paquete app_pasajero
      theme: AppTheme.lightTheme,
      home: const LoginScreen(),
    );
  }
}
