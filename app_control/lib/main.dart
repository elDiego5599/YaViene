import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'core/router/app_router.dart';
import 'features/auth/presentation/providers/auth_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  const windowOptions = WindowOptions(
    size: Size(1600, 900),
    center: true,
    fullScreen: true,
    title: 'Ya Viene · Control',
  );
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  final container = ProviderContainer();
  await container.read(authProvider.notifier).restoreSession();
  runApp(UncontrolledProviderScope(container: container, child: const YaVieneControlApp()));
}

class YaVieneControlApp extends ConsumerWidget {
  const YaVieneControlApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'Ya Viene - Control',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF14274E)),
        scaffoldBackgroundColor: const Color(0xFFF8F9FA),
      ),
      routerConfig: router,
    );
  }
}
