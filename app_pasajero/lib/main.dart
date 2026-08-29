library;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

import 'config.dart';
import 'core/router/app_router.dart';
import 'core/router/app_transitions.dart';
import 'core/services/bus_notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (e, st) {
    debugPrint('Firebase init falló: $e\n$st');
    runApp(const _FirebaseInitFailedApp());
    return;
  }
  // El plugin de notificaciones no debe impedir que la app abra si falla la
  // inicialización (los avisos fallan blando más adelante).
  try {
    await BusNotificationService.init();
  } catch (_) {
    debugPrint('notificaciones: init falló, los avisos quedan desactivados');
  }

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
  );

  runApp(
    ProviderScope(
      // El paquete compartido no adivina la URL: se la da la app, que es
      // quien tiene el `--dart-define` y quien sabe explicar que falta.
      overrides: [backendUrlProvider.overrideWithValue(AppConfig.backendUrl)],
      child: const YaVieneApp(),
    ),
  );
}

class _FirebaseInitFailedApp extends StatelessWidget {
  const _FirebaseInitFailedApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_rounded,
                    size: 48, color: AppColors.error),
                const SizedBox(height: 16),
                const Text(
                  'No se pudo iniciar Ya Viene',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Revisa tu conexión e intenta de nuevo. Si persiste, reinstala la app.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () async {
                    try {
                      await Firebase.initializeApp();
                      runApp(ProviderScope(
                        overrides: [
                          backendUrlProvider
                              .overrideWithValue(AppConfig.backendUrl),
                        ],
                        child: const YaVieneApp(),
                      ));
                    } catch (e, st) {
                      debugPrint('Reintento Firebase falló: $e\n$st');
                    }
                  },
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class YaVieneApp extends ConsumerWidget {
  const YaVieneApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    const fadeSlide = PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeSlidePageTransitionsBuilder(),
        TargetPlatform.iOS: FadeSlidePageTransitionsBuilder(),
        TargetPlatform.macOS: FadeSlidePageTransitionsBuilder(),
      },
    );

    return MaterialApp.router(
      title: 'Ya Viene',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme.copyWith(pageTransitionsTheme: fadeSlide),
      darkTheme: AppTheme.lightTheme.copyWith(pageTransitionsTheme: fadeSlide),
      themeMode: ThemeMode.light,
      routerConfig: router,
      locale: const Locale('es', 'CO'),
    );
  }
}
