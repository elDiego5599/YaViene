import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

/// Pantalla de referencia: iPhone 14/15, en puntos.
///
/// Un solo tamaño para todas las fotos. Lo que estas pruebas vigilan es la
/// tipografía, el color y el espaciado; probar cada pantalla en tres
/// tamaños multiplicaría las fotos sin cazar nada que este no cace.
const Size kPantalla = Size(390, 844);

/// Muescas de un iPhone con indicador de inicio.
///
/// No son decoración: la hoja del selector mide `viewPadding.bottom` para
/// meter el inset dentro de la tarjeta, y la píldora de búsqueda cuelga de
/// un `SafeArea`. Con márgenes en cero las dos se pintan en un sitio en el
/// que nunca están.
const FakeViewPadding kMargenesSeguros = FakeViewPadding(top: 47, bottom: 34);

/// Fija la ventana de la prueba y la devuelve a su sitio al terminar.
///
/// Con `devicePixelRatio` en 1 la foto sale del tamaño exacto en puntos:
/// se lee a ojo en un visor y no ocupa cuatro veces más en el repositorio.
/// Los márgenes van en la ventana y no solo en un `MediaQuery` anidado
/// porque hay pantallas que se muestran como diálogo (`RouteSelectorSheet`
/// vive en un `showGeneralDialog`): esas cuelgan del `Navigator` del
/// `MaterialApp`, o sea POR ENCIMA de cualquier `MediaQuery` que pongamos
/// dentro de `home`, y solo ven lo que diga la ventana.
void fijarPantalla(
  WidgetTester tester, {
  Size tamano = kPantalla,
  double escalaTexto = 1.0,
}) {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = tamano;
  tester.view.padding = kMargenesSeguros;
  tester.view.viewPadding = kMargenesSeguros;
  addTearDown(tester.view.reset);
  // La escala va en el dispatcher y no en un `MediaQuery` anidado por la
  // misma razón que las muescas: hay pantallas que se montan como diálogo
  // y no ven nada de lo que cuelgue de `home`.
  if (escalaTexto != 1.0) {
    tester.platformDispatcher.textScaleFactorTestValue = escalaTexto;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }
}

/// Envuelve [hijo] como lo ve la app de verdad.
///
/// El tema va explícito porque el resto de las pruebas monta un
/// `MaterialApp` pelado: sin esto la foto saldría con la tipografía de
/// Material y no con la nuestra, y la prueba no vigilaría nada.
Widget marcoGolden(Widget hijo) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.lightTheme,
    locale: const Locale('es', 'CO'),
    // El tamaño y las muescas los pone `fijarPantalla` en la ventana, no
    // aquí: así los ve igual lo que se monta en `home` y lo que se abre
    // como diálogo.
    home: Builder(
      // El `Material` no es adorno: es quien baja la tipografía del tema al
      // `DefaultTextStyle`. Sin él, un `Text` sin familia propia cae en la
      // fuente por defecto del motor de pruebas y la foto sale con letra
      // que no es la nuestra. En la app siempre hay un `Scaffold` encima,
      // así que esto reproduce lo que pasa de verdad; `transparency` lo
      // deja sin pintar nada propio.
      builder: (context) =>
          Material(type: MaterialType.transparency, child: hijo),
    ),
  );
}

/// Igual que [marcoGolden] pero con un `GoRouter` de una sola ruta.
///
/// Hay pantallas que preguntan por la ruta actual (el login lee
/// `GoRouterState.of(context)` para saber si llegó desde el splash con un
/// aviso de sesión). Sin router revientan al construirse.
Widget marcoGoldenRuteado(Widget hijo, {String ruta = '/'}) {
  return MaterialApp.router(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.lightTheme,
    locale: const Locale('es', 'CO'),
    routerConfig: GoRouter(
      initialLocation: ruta,
      routes: [
        GoRoute(
          path: ruta,
          builder: (context, state) =>
              Material(type: MaterialType.transparency, child: hijo),
        ),
      ],
    ),
  );
}

/// Compara la pantalla con su foto de referencia.
///
/// Para regenerarlas: `flutter test --update-goldens test/golden`.
/// Una foto solo se actualiza cuando el cambio visual es a propósito, y el
/// commit dice cuál es el cambio y por qué.
Future<void> coincideConOro(WidgetTester tester, String nombre) async {
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('goldens/$nombre.png'),
  );
}
