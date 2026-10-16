library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/buzon/presentation/buzon_screen.dart';
import '../../features/legal/legal_docs.dart';
import '../../features/legal/presentation/screens/legal_screen.dart';
import '../../features/map/presentation/screens/map_screen.dart';
import '../../features/mas/presentation/mas_screen.dart';
import '../../features/notifications/presentation/screens/notifications_screen.dart';
import '../../features/onboarding/presentation/screens/onboarding_screen.dart';
import '../../features/splash/presentation/screens/splash_screen.dart';
import 'shell_pildora.dart';

abstract class AppRoutes {
  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String map = '/map';
  static const String notifications = '/notifications';
  static const String routeDetail = '/route/:routeId';
  static const String alertSettings = '/alerts';

  /// El buzón de problemas y sugerencias (D14 del backend).
  static const String buzon = '/buzon';

  /// La cuarta pestaña: la guía, lo legal y los créditos, lo que antes
  /// vivía en el menú lateral.
  static const String mas = '/mas';

  /// Privacidad y términos, uno por documento: `/legal/privacidad`.
  static const String legal = '/legal/:doc';
}

/// El camino de un documento legal, para no escribirlo a mano en cada sitio
/// que lo abre (la bienvenida y Más).
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
      // Las cuatro pestañas de la píldora de abajo (dueño, 2026-10-16). Cada
      // una guarda su pantalla viva al cambiar de pestaña, como en iOS: el
      // mapa no se vuelve a montar ni el buzón pierde lo escrito. Lo legal
      // va fuera, encima de la píldora, con su flecha de volver.
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) =>
            ShellConPildora(navigationShell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.map,
              name: 'map',
              builder: (context, state) => const MapScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.notifications,
              name: 'notifications',
              builder: (context, state) => const NotificationsScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.buzon,
              name: 'buzon',
              builder: (context, state) => const BuzonScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.mas,
              name: 'mas',
              builder: (context, state) => const MasScreen(),
            ),
          ]),
        ],
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
