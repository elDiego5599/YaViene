library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

import 'config.dart';
import 'core/router/app_router.dart';
import 'core/router/app_transitions.dart';
import 'core/services/bus_notification_service.dart';
import 'core/widgets/ink_hero.dart';
import 'features/notifications/data/avisos_push.dart';
import 'features/notifications/presentation/providers/proximity_alerts_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lo primero es pintar. Antes el primer cuadro de Flutter salía después de
  // saber a qué backend hablar, y esa pregunta va en serie:
  // hasta 3 s por el principal y, si no contesta, hasta 20 s más por el
  // respaldo (BackendResolver). Todo ese rato el teléfono se quedaba en la
  // pantalla nativa, quieta, sin decir si la app seguía viva. Preguntar a los
  // dos a la vez acortaría la espera, pero despertaría la máquina de respaldo
  // en cada arranque aunque el principal conteste; la pregunta sigue en serie
  // y lo que cambia es que la espera se ve.
  runApp(const _ArranqueTemprano());

  // Se lanza ya y se espera al final: la pregunta por el backend viaja
  // mientras se preparan las notificaciones y la pantalla, y en el caso
  // normal —el backend de siempre contesta— no le suma nada al arranque.
  final backendUrl = BackendResolver.resolver(
    principal: AppConfig.backendUrl,
    respaldo: AppConfig.fallbackBackendUrl,
  );

  // El plugin de notificaciones no debe impedir que la app abra si falla la
  // inicialización (los avisos fallan blando más adelante).
  try {
    await BusNotificationService.init();
  } catch (_) {
    debugPrint('notificaciones: init falló, los avisos quedan desactivados');
  }

  // Los avisos con la app cerrada (Android). Falla blando por dentro: sin
  // Firebase la app sigue avisando mientras está abierta.
  await AvisosPush.iniciar(alRecibirPushEnFondo);

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

  final url = await backendUrl;
  runApp(
    ProviderScope(
      // El paquete compartido no adivina la URL: se la da la app, que es
      // quien tiene el `--dart-define` y quien sabe explicar que falta.
      overrides: [backendUrlProvider.overrideWith(() => _backendUrl(url))],
      child: const YaVieneApp(),
    ),
  );
}

/// La URL que eligió el arranque, junto con las dos candidatas: si deja de
/// contestar con la app abierta, se vuelve a elegir entre ellas sin reiniciar.
BackendUrl _backendUrl(String elegida) => BackendUrl(
      elegida,
      principal: AppConfig.backendUrl,
      respaldo: AppConfig.fallbackBackendUrl,
    );

/// Primer cuadro de la app mientras se resuelve el backend.
///
/// Es una copia de la pantalla de arranque nativa, no una pantalla nueva: el
/// mismo fondo de tinta y el logo de 84 en el mismo sitio, así que el relevo
/// nativa → Flutter no se nota. Para que el logo caiga justo donde después lo
/// deja el splash se usa el mismo `InkHero` con las mismas medidas; el nombre
/// y la tagline van montados pero invisibles (ocupan su hueco y no se leen),
/// porque el splash los hace entrar y, si ya estuvieran a la vista, se
/// apagarían un instante en el relevo. Tampoco va el fondo de rutas: el
/// splash lo arranca desde cero y aquí solo lo haría saltar.
class _ArranqueTemprano extends StatefulWidget {
  const _ArranqueTemprano();

  @override
  State<_ArranqueTemprano> createState() => _ArranqueTempranoState();
}

class _ArranqueTempranoState extends State<_ArranqueTemprano> {
  /// Lo normal es que esta pantalla dure lo que tarda el backend en contestar,
  /// unos cientos de milisegundos, y ahí no debe asomar nada: el indicador
  /// aparecería y se iría al relevarla el splash. Solo si la espera pasa de
  /// 1,5 s —ya no es un arranque normal; casi siempre es que el principal no
  /// contesta— entra el indicador, para decir que la app está viva.
  static const Duration _paciencia = Duration(milliseconds: 1500);

  late final Timer _timer;
  bool _lento = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(_paciencia, () {
      if (mounted) setState(() => _lento = true);
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  /// Monta la pieza con su tamaño pero sin mostrarla. Con opacidad 0,
  /// `Opacity` la saca también del árbol de accesibilidad.
  static Widget _invisible(
    Widget child, {
    double start = 0,
    Offset begin = Offset.zero,
  }) =>
      Opacity(opacity: 0, child: child);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: Scaffold(
        backgroundColor: AppColors.ink,
        body: Center(
          child: InkHero(
            // Las mismas medidas que SplashScreen y que la pantalla nativa.
            logoSize: 84,
            spacingAfterLogo: 20,
            // Sin vuelo: esta app se desmonta entera cuando llega la de
            // verdad, no hay pantalla a la que volar.
            heroTag: null,
            entradaEscalonada: _invisible,
            trailing: AnimatedOpacity(
              opacity: _lento ? 1 : 0,
              duration: AppMotion.normal,
              // El mismo tamaño que el indicador del splash: con otro, la
              // columna mediría distinto y el logo quedaría corrido.
              child: const IndicadorCarga(
                size: 26,
                color: Color.fromRGBO(255, 255, 255, 0.75),
                semanticsLabel: 'Conectando con Ya Viene',
              ),
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

    return MaterialApp.router(
      title: 'Ya Viene',
      debugShowCheckedModeBanner: false,
      theme:
          AppTheme.lightTheme.copyWith(pageTransitionsTheme: transicionesApp),
      darkTheme:
          AppTheme.lightTheme.copyWith(pageTransitionsTheme: transicionesApp),
      themeMode: ThemeMode.light,
      routerConfig: router,
      // El idioma no es solo el texto que escribimos nosotros: sin los
      // delegates, los menús que dibuja el sistema (copiar, pegar,
      // seleccionar todo) y los tooltips salen en inglés.
      locale: const Locale('es', 'CO'),
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('es', 'CO'), Locale('es')],
    );
  }
}
