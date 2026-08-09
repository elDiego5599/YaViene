
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/map/presentation/screens/map_screen.dart';
import '../../features/notifications/presentation/screens/notifications_screen.dart';

abstract class AppRoutes {
  static const String login = '/';
  static const String map = '/map';
  static const String notifications = '/notifications';
  static const String routeDetail = '/route/:routeId';
  static const String alertSettings = '/alerts';
}

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    debugLogDiagnostics: true,
    initialLocation: AppRoutes.login,
    routes: [
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        builder: (context, state) => const PremiumLoginScreen(),
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
