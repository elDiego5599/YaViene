
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/otp_verification_screen.dart';
import '../../features/map/presentation/screens/map_screen.dart';

abstract class AppRoutes {
  static const String login = '/';
  static const String otp = '/otp';
  static const String map = '/map';
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
        path: AppRoutes.otp,
        name: 'otp',
        builder: (context, state) {
          final phone = state.extra as String? ?? '';
          return OtpVerificationScreen(phoneNumber: phone);
        },
      ),
      GoRoute(
        path: AppRoutes.map,
        name: 'map',
        builder: (context, state) => const MapScreen(),
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
