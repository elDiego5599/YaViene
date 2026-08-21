library;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

import 'core/router/app_router.dart';
import 'core/router/app_transitions.dart';
import 'core/services/bus_notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
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
