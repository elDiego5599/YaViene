/// =============================================================================
/// ROUTER CENTRALIZADO (GoRouter)
///
/// Define todas las rutas de la aplicación en un solo lugar.
/// Se expone como un Provider de Riverpod para poder inyectar dependencias
/// (ej. estado de autenticación) en el futuro sin refactorizar nada.
/// =============================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/map/presentation/screens/map_screen.dart';

/// Rutas nombradas para evitar strings mágicos en el código.
abstract class AppRoutes {
  static const String map = '/';
  static const String routeDetail = '/route/:routeId';
  static const String alertSettings = '/alerts';
}

/// Provider del router. Al ser un Provider simple (no StateProvider),
/// GoRouter se instancia una sola vez y se reutiliza.
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    debugLogDiagnostics: true,
    initialLocation: AppRoutes.map,
    routes: [
      GoRoute(
        path: AppRoutes.map,
        name: 'map',
        builder: (context, state) => const MapScreen(),
      ),
      // FUTURO: Agregar rutas de detalle de ruta y configuración de alertas
      // GoRoute(path: AppRoutes.routeDetail, ...),
      // GoRoute(path: AppRoutes.alertSettings, ...),
    ],
    errorBuilder: (context, state) => const _NotFoundScreen(),
  );
});

/// Pantalla de error 404 interna — no debería verse en producción.
class _NotFoundScreen extends StatelessWidget {
  const _NotFoundScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text('Ruta no encontrada', style: Theme.of(context).textTheme.bodyLarge),
      ),
    );
  }
}

// Importación necesaria para el StatelessWidget interno
import 'package:flutter/material.dart';
