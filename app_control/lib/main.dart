import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

// Solo el provider de la URL: el resto del paquete choca con el tema local.
import 'package:ya_viene_core/core/providers/app_providers.dart'
    show backendUrlProvider;

import 'config.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/providers/auth_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
    try {
      await windowManager.ensureInitialized();
      const windowOptions = WindowOptions(
        size: Size(1600, 900),
        center: true,
        title: 'Ya Viene Control',
      );
      windowManager.waitUntilReadyToShow(windowOptions, () async {
        await windowManager.show();
        await windowManager.maximize();
        await windowManager.focus();
      });
    } catch (e) {
      debugPrint('windowManager init falló: $e');
    }
  }

  final container = ProviderContainer(
    overrides: [backendUrlProvider.overrideWithValue(AppConfig.backendUrl)],
  );
  try {
    await container.read(authProvider.notifier).restoreSession();
  } catch (e) {
    debugPrint('restoreSession falló en el arranque: $e');
  }
  runApp(UncontrolledProviderScope(container: container, child: const YaVieneControlApp()));
}

class YaVieneControlApp extends ConsumerWidget {
  const YaVieneControlApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'Ya Viene Control',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: router,
    );
  }
}
