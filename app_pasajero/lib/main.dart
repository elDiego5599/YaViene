/// =============================================================================
/// PUNTO DE ENTRADA DE LA APLICACIÓN
/// Envuelve toda la app en ProviderScope (Riverpod) para que los providers
/// estén disponibles globalmente. La app está forzada a Light Mode y usa el
/// router centralizado.
/// =============================================================================

library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ya_viene_core/ya_viene_core.dart';
import 'core/router/app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Forzar orientación vertical — la app no debe rotarse en el uso cotidiano
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Estilo de la barra de estado: iconos oscuros sobre fondo claro
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
  );

  runApp(
    // ProviderScope es el contenedor raíz de todos los providers de Riverpod
    const ProviderScope(
      child: YaVieneApp(),
    ),
  );
}

class YaVieneApp extends ConsumerWidget {
  const YaVieneApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'Ya Viene',
      debugShowCheckedModeBanner: false,

      // ── TEMA: Solo Light Mode, sin posibilidad de toggle ──────────────────
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.lightTheme, // El dark theme también usa light
      themeMode: ThemeMode.light, // Forzado al modo claro

      // ── NAVEGACIÓN ────────────────────────────────────────────────────────
      routerConfig: router,

      // ── LOCALIZACIÓN ─────────────────────────────────────────────────────
      locale: const Locale('es', 'CO'),
    );
  }
}
