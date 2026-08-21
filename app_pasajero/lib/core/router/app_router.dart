library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/auth_provider.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/map/presentation/screens/map_screen.dart';
import '../../features/notifications/presentation/screens/notifications_screen.dart';
import '../../features/onboarding/presentation/screens/onboarding_screen.dart';
import '../../features/splash/presentation/screens/splash_screen.dart';

abstract class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';
  static const String onboarding = '/onboarding';
  static const String map = '/map';
  static const String notifications = '/notifications';
  static const String routeDetail = '/route/:routeId';
  static const String alertSettings = '/alerts';
}

final appRouterProvider = Provider<GoRouter>((ref) {
  // Rutas que requieren sesión iniciada: sin cuenta, cualquier intento de
  // llegar aquí rebota al login. Anti-tontos: aunque un camino interno o un
  // deep link intentara saltarse el inicio de sesión, el mapa y sus pantallas
  // quedan inaccesibles sin un usuario verificado.
  const protected = {
    AppRoutes.onboarding,
    AppRoutes.map,
    AppRoutes.notifications,
  };
  // Mantener el router pendiente del estado de auth: si la sesión se revoca o
  // se cierra en segundo plano, el redirect vuelve a evaluarse y expulsa al
  // usuario de las rutas protegidas sin esperar a una navegación explícita.
  final authNotifier = ref.read(authProvider);
  return GoRouter(
    debugLogDiagnostics: true,
    initialLocation: AppRoutes.splash,
    refreshListenable: authNotifier,
    redirect: (context, state) {
      // Leer el estado del notifier capturado, no `ref.read`: durante la
      // notificación de GoRouteInformationProvider el elemento del provider
      // aún tiene su dependencia cambiada y cualquier `ref` asertaría.
      final auth = authNotifier.state;
      if (auth.status != AuthStatus.verified &&
          protected.contains(state.matchedLocation)) {
        return AppRoutes.login;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        builder: (context, state) => const PremiumLoginScreen(),
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
