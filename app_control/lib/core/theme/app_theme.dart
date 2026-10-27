import 'package:flutter/material.dart';
import 'package:ya_viene_core/ya_viene_core.dart' as core;

/*
  El panel de control usa el mismo sistema de diseño que la app del pasajero.
  No es una copia de sus valores: los toma de `ya_viene_core`, que es donde
  viven. Antes tenía paleta propia, tipografía propia (Inter por red) y su
  propio dibujo del bus, y con cada retoque de la app se separaba un poco
  más hasta parecer otro producto.

  Lo que sí es propio de aquí son los nombres de estado —`online`, `ghost`,
  `hidden`, `offline`— porque describen algo que sólo existe en el panel: en
  qué situación está un bus de la flota. Cada uno apunta al color que le
  corresponde en el sistema.
*/
abstract class AppColors {
  /// Fondo de la consola. Arena, la superficie cálida de la marca: es lo que
  /// hace que el panel se lea como parte del mismo producto y no como un
  /// tablero gris cualquiera.
  static const Color bg = core.AppColors.arena;
  static const Color surface = core.AppColors.surface;

  /// Superficie de la tarjeta de entrada. Mismo arena que la hoja de login
  /// del pasajero, y por el mismo motivo: era blanca, y contra el fondo de
  /// tinta parecía una pantalla prestada de otro producto. Vive aparte de
  /// [bg] porque ahí arena es fondo y aquí es la tarjeta que va encima.
  static const Color sheet = core.AppColors.arena;
  static const Color surfaceRaised = core.AppColors.surfaceMuted;
  static const Color border = core.AppColors.divider;

  /// Un paso más de contraste que [border], para lo que tiene que leerse
  /// como borde de control (campos, botones fantasma) y no como separación.
  /// No está en el sistema porque el pasajero no tiene formularios así.
  static const Color borderStrong = Color(0xFFD8DBE0);

  /// El azul de la consola: íconos, texto y bordes de foco.
  /// Era la tinta del sistema (#0B1628) y el dueño la vio muy oscura, sin
  /// vida; este es el azul de lo alto del menú lateral del pasajero
  /// (`LiveRouteBackdrop`), el mismo con que arranca el degradado del 404
  /// de la web. Con él el blanco encima queda en 12,7:1 y como letra sobre
  /// blanco o arena sigue por encima de 11:1.
  static const Color navy = Color(0xFF17325F);

  /// El fondo de lo que va lleno —botones, el filtro de ruta y la pestaña
  /// de estado activos—: el mismo azul de los botones del pasajero
  /// (#1E56A8). El dueño lo eligió solo para eso, no para íconos, y vio
  /// que el panel pintaba lo activo en [navy] y parecía otro azul
  /// (2026-09-28). Blanco encima da 7,1:1.
  static const Color boton = core.AppColors.acento;
  static const Color navyRaised = core.AppColors.primaryDeep;

  static const Color textPrimary = core.AppColors.textPrimary;
  static const Color textSecondary = core.AppColors.textSecondary;

  /// Rótulos, pistas, pies y los íconos de apoyo. Es el mismo gris que el
  /// pasajero usa para eso, porque es el más claro que pasa el 4,5:1 sobre
  /// la arena del fondo y sobre el blanco de las tarjetas;
  /// [core.AppColors.textDisabled] se queda en 2,4:1 y no se lee en un
  /// proyector ni con la vista cansada (test/accesibilidad_panel_test.dart).
  /// Lo que lo separa del texto de al lado es el tamaño, el peso y el
  /// espaciado, no un gris más pálido.
  static const Color textMuted = core.AppColors.textSecondary;

  /*
    Los cuatro estados de un bus. Eran dos colores para cuatro palabras:
    «Inactivo», «Sin señal» y «Oculto» apuntaban los tres al mismo gris, así
    que sobre el mapa un bus con el equipo trabado, uno que dejó de
    transmitir y uno que el operador apagó a mano se dibujaban idénticos, y
    el operador tenía que abrir la ficha para saber cuál era cuál (YV-29).

    Ahora cada uno tiene el suyo, y los cuatro son variantes accesibles que
    ya existían en el sistema: pasan 4,5:1 sobre el blanco de las tarjetas y
    sobre la arena del escritorio, que es lo que pide la norma para texto
    chico —el rótulo del estado mide entre 8 y 12 pt—. Ninguno de los cuatro
    trabaja solo: cada estado lleva también su ícono (`BusEstado.icono`),
    porque un operador que no distingue verde de ámbar, o un proyector que
    lava los colores, dejan el panel sin información.
  */

  /// Transmitiendo. El verde de la marca (#00A859) da 3,1:1 sobre blanco:
  /// no alcanza ni para el rótulo ni para el texto blanco de un botón. Este
  /// es ese mismo verde en su variante accesible.
  static const Color online = core.AppColors.primaryAccessible;

  /// Lo puesto (la pestaña Flota o Reportes, la ruta elegida y «En línea»),
  /// lleno en el verde oscuro de la marca con la letra blanca encima
  /// (5,48:1; dueño, 2026-10-27; antes el verde claro con letra verde).
  static const Color capsula = core.AppColors.primaryAccessible;

  /// «Sin conexión», lleno con la letra blanca: el rojo de la web
  /// (`--coral-accessible`, #CE2D1D), más fuerte que [danger]; blanco encima
  /// da 5,23:1 (dueño, 2026-10-27).
  static const Color sinConexion = Color(0xFFCE2D1D);

  /// El filo de la píldora de las pestañas, el mismo de la del pasajero.
  static const Color filoPildora = core.AppColors.hairline;

  /// Lleva más de 90 s sin mandar posición pero la sesión sigue viva. Ámbar,
  /// que en el sistema significa «reintenta o espera»: el bus está ahí y lo
  /// que falla es el equipo, no el turno.
  static const Color ghost = core.AppColors.warningAccessible;

  /// No está transmitiendo. Coral, que es lo que el sistema reserva para la
  /// excepción ya confirmada —«bus sin señal» con esas palabras—, en su
  /// variante para glifos y letras.
  static const Color offline = core.AppColors.coralAccessible;

  /// El operador lo quitó del mapa del pasajero. Gris, y a propósito: es una
  /// decisión suya, no una avería, y no debe pedir atención como las otras
  /// dos. Antes compartía gris con «sin señal», que era justo la confusión
  /// que había que deshacer.
  static const Color hidden = core.AppColors.textSecondary;

  static const Color danger = core.AppColors.error;

  /// El bus que el operador tiene abierto en la ficha. En la app este azul
  /// está reservado a la ruta que le importa al usuario; aquí a lo que le
  /// importa al operador. Es el único azul del mapa, así que el halo se ve
  /// venir sin competir con el verde ni con el gris.
  static const Color selection = core.AppColors.electricBlue;

  // El bus sobre el mapa tenía aquí dos colores propios —uno activo y uno
  // gris— y era la tercera lista de estados del panel: la fila conocía tres
  // situaciones, la leyenda otras tres y el marcador solo dos. Ya no existen:
  // el marcador pinta el color del estado como todo lo demás, y quién está en
  // qué estado lo decide `BusEstado`, que es el único sitio con esa regla.
  //
  // Lo que sí se queda es que el bus del mapa va en verde y no en el coral
  // del pasajero. Nació porque OpenStreetMap pintaba las arterias en salmón
  // y el coral se perdía encima; desde que el panel pinta el mismo Voyager
  // del pasajero (2026-09-30) esa razón ya no está, pero el verde es el del
  // estado «en línea», y así lo lee el operador.

  // Las sombras del panel, propias y no las de `core.AppShadows`, que
  // comparte el pasajero. Más realzadas que la suave de antes (5 %, 12 de
  // difuminado), que sobre el fondo blanco no despegaba nada (dueño,
  // 2026-10-07). Dos capas, como una luz de verdad: una corta y nítida que
  // asienta el borde y una larga, recogida hacia dentro (`spreadRadius`
  // negativo), que da la altura sin ensuciar los lados. En el marino de la
  // marca y no en negro, para que no se lean grises. La maqueta de la web
  // no las copia: allí no pesan lo que cuestan (dueño, 2026-10-07).

  /// La barra de arriba sobre el tablero: solo hacia abajo.
  static const List<BoxShadow> sombraCabecera = [
    BoxShadow(
      color: Color(0x1414274E), // 8 %
      blurRadius: 12,
      spreadRadius: -4,
      offset: Offset(0, 4),
    ),
  ];

  /// La lista, el mapa y los globos de ayuda: apoyados en el tablero.
  static const List<BoxShadow> sombraTarjeta = [
    BoxShadow(
      color: Color(0x0F14274E), // 6 %
      blurRadius: 3,
      offset: Offset(0, 1),
    ),
    BoxShadow(
      color: Color(0x1F14274E), // 12 %
      blurRadius: 24,
      spreadRadius: -6,
      offset: Offset(0, 10),
    ),
  ];

  /// Lo que va encima del mapa o del velo: la leyenda, la ficha del bus,
  /// los avisos y las ventanas.
  static const List<BoxShadow> sombraFlotante = [
    BoxShadow(
      color: Color(0x1414274E), // 8 %
      blurRadius: 6,
      offset: Offset(0, 2),
    ),
    BoxShadow(
      color: Color(0x2914274E), // 16 %
      blurRadius: 40,
      spreadRadius: -10,
      offset: Offset(0, 20),
    ),
  ];
}

/// Los radios del sistema. El panel usaba nueve valores distintos entre 8 y
/// 24 puestos a ojo; estos son los mismos cuatro de la app.
abstract class AppRadius {
  static const double sm = core.AppRadius.sm;
  static const double md = core.AppRadius.md;
  static const double lg = core.AppRadius.lg;
  static const double card = core.AppRadius.card;
  static const double pill = core.AppRadius.pill;
}

/*
  Tipografía. Sustituye a `GoogleFonts.inter(...)` con la misma forma de
  llamada, así que el cambio no obligó a reescribir setenta estilos: la
  familia es la de la marca y viaja en el bundle.

  `mono` no es monoespaciada: es la misma familia con cifras de ancho fijo.
  Se usa donde los números tienen que quedar alineados o donde se lee un
  dato de máquina —una placa, un estado— y ahí lo que importa es que las
  columnas no bailen, no que la letra sea de máquina de escribir.
*/
abstract class AppType {
  static const String family = 'PlusJakartaSans';

  static TextStyle ui({
    double? fontSize,
    FontWeight? fontWeight,
    double? letterSpacing,
    double? height,
    Color? color,
    FontStyle? fontStyle,
    TextDecoration? decoration,
    List<FontFeature>? fontFeatures,
  }) {
    return TextStyle(
      fontFamily: family,
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
      height: height,
      color: color,
      fontStyle: fontStyle,
      decoration: decoration,
      fontFeatures: fontFeatures,
    );
  }

  static TextStyle mono({
    double? fontSize,
    FontWeight? fontWeight,
    double? letterSpacing,
    double? height,
    Color? color,
  }) {
    return ui(
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
      height: height,
      color: color,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }
}

abstract class AppTheme {
  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.navy,
        brightness: Brightness.light,
        surface: AppColors.surface,
      ),
      scaffoldBackgroundColor: AppColors.bg,
      fontFamily: AppType.family,
    );

    return base.copyWith(
      textTheme: base.textTheme.apply(
        fontFamily: AppType.family,
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        hintStyle: AppType.ui(color: AppColors.textMuted),
        labelStyle: AppType.ui(color: AppColors.textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.borderStrong),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.borderStrong),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.navy, width: 1.6),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.boton,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: AppType.ui(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.textSecondary,
          textStyle: AppType.ui(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.white
              : AppColors.textMuted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.online
              : AppColors.borderStrong,
        ),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      // El globo de ayuda de los botones de icono —«Editar bus», «Renombrar
      // ruta»— salía en el gris de fábrica con esquinas de 4, lo único del
      // panel que no era del panel. Va en el azul de la consola, con el
      // radio chico del sistema y la letra de la marca: el blanco encima da
      // 12,7:1. 10×6 por dentro es el aire de una píldora de una línea.
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.navy,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          boxShadow: AppColors.sombraTarjeta,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        textStyle: AppType.ui(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      cardTheme: const CardThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.lg)),
          side: BorderSide(color: AppColors.border),
        ),
      ),
    );
  }
}
