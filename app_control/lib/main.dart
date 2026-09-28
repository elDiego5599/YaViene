import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

// Solo el provider de la URL y el resolutor: el resto del paquete choca con
// el tema local.
import 'package:ya_viene_core/core/network/backend_resolver.dart'
    show BackendResolver;
import 'package:ya_viene_core/core/providers/app_providers.dart'
    show BackendUrl, backendUrlProvider;

import 'config.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/providers/auth_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Se lanza antes de abrir la ventana y se espera justo antes de crear el
  // contenedor: así la pregunta por el backend viaja mientras se monta la
  // ventana, en vez de sumarse a ese tiempo.
  final backendUrl = BackendResolver.resolver(
    principal: AppConfig.backendUrl,
    respaldo: AppConfig.fallbackBackendUrl,
  );

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

  final url = await backendUrl;
  final container = ProviderContainer(
    overrides: [
      backendUrlProvider.overrideWith(() => BackendUrl(
            url,
            principal: AppConfig.backendUrl,
            respaldo: AppConfig.fallbackBackendUrl,
          )),
    ],
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
      // El tamaño de letra del sistema se respeta hasta 2×, como en el
      // pasajero. Windows deja subirlo más (225 %), y ahí la fila de un bus
      // no desbordaba pero el nombre del conductor, que entonces llevaba,
      // quedaba en 47 de sus 462 puntos: solo se leían los puntos
      // suspensivos (test/escalado_texto_test.dart).
      builder: (context, child) => MediaQuery.withClampedTextScaling(
        maxScaleFactor: 2.0,
        child: child!,
      ),
    );
  }
}
