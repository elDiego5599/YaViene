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

  static const Color navy = core.AppColors.ink;
  static const Color navyRaised = core.AppColors.primaryDeep;

  static const Color textPrimary = core.AppColors.textPrimary;
  static const Color textSecondary = core.AppColors.textSecondary;
  static const Color textMuted = core.AppColors.textDisabled;

  /// Transmitiendo.
  static const Color online = core.AppColors.primary;

  /// Lleva más de 90 s sin mandar posición pero la sesión sigue viva.
  static const Color ghost = core.AppColors.busGhost;

  /// El color de la acción de ocultar un bus: coral, que en el sistema es
  /// «excepción» —esto lo es, un bus que existe y que se decide no enseñar.
  static const Color hidden = core.AppColors.coral;

  static const Color offline = core.AppColors.busGhost;
  static const Color danger = core.AppColors.error;

  /// El bus que el operador tiene abierto en la ficha. En la app este azul
  /// está reservado a la ruta que le importa al usuario; aquí a lo que le
  /// importa al operador. Es el único azul del mapa, así que el halo se ve
  /// venir sin competir con el coral ni con el gris.
  static const Color selection = core.AppColors.electricBlue;

  /// El bus sobre el mapa, exactamente el del pasajero: coral si reporta,
  /// gris si no. El operador tiene que ver el mismo icono que ve el usuario.
  static const Color busActive = core.AppColors.busActive;
  static const Color busGhost = core.AppColors.busGhost;

  static List<BoxShadow> get softShadow => core.AppShadows.soft;
  static List<BoxShadow> get floatingShadow => core.AppShadows.floating;
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
          backgroundColor: AppColors.navy,
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
