library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/legal/legal_docs.dart';
import '../../features/legal/presentation/screens/legal_screen.dart';
import '../../features/map/presentation/screens/map_screen.dart';
import '../../features/notifications/presentation/screens/notifications_screen.dart';
import '../../features/onboarding/presentation/screens/onboarding_screen.dart';
import '../../features/splash/presentation/screens/splash_screen.dart';

abstract class AppRoutes {
  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String map = '/map';
  static const String notifications = '/notifications';
  static const String routeDetail = '/route/:routeId';
  static const String alertSettings = '/alerts';

  /// Privacidad y términos, uno por documento: `/legal/privacidad`.
  static const String legal = '/legal/:doc';
}

/// El camino de un documento legal, para no escribirlo a mano en cada sitio
/// que lo abre (la bienvenida y el menú).
String legalPath(String docId) => '/legal/$docId';

// Sin cuenta ni redirect: el pasajero entra directo (D3). El backend nunca
// usó la sesión para nada —el mapa, los buses y los avisos no dependen de
// quién mira—, así que el login solo era una puerta delante del mapa.
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    debugLogDiagnostics: true,
    initialLocation: AppRoutes.splash,
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        name: 'onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: AppRoutes.map,
        name: 'map',
        builder: (context, state) => const MapScreen(),
      ),
      GoRoute(
        path: AppRoutes.legal,
        name: 'legal',
        builder: (context, state) {
          final doc = legalDocById(state.pathParameters['doc']);
          // Un documento inventado no pinta una pantalla en blanco con una
          // barra sin título: sale por donde sale cualquier ruta que no
          // existe.
          return doc == null ? const _NotFoundScreen() : LegalScreen(doc: doc);
        },
      ),
      GoRoute(
        path: AppRoutes.notifications,
        name: 'notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
    ],
    errorBuilder: (context, state) => const _NotFoundScreen(),
  );
});

class _NotFoundScreen extends StatelessWidget {
  const _NotFoundScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text('Ruta no encontrada',
            style: Theme.of(context).textTheme.bodyLarge),
      ),
    );
  }
}
