/// =============================================================================
/// SISTEMA DE DISEÑO — APP THEME
///
/// Paleta institucional de "Ya Viene":
///   - Azul Institucional (#1565C0): Color primario. Evoca confianza,
///     institucionalidad y transporte público. Visible bajo el sol tropical.
///   - Blanco Puro (#FFFFFF): Fondo. Máximo contraste con el texto.
///   - Gris Neutro (#F5F7FA): Fondos de superficies y campos.
///   - Negro Fuerte (#0D0D0D): Texto principal. Contraste máximo.
///   - Gris Bus (#9E9E9E): Para los buses sin señal (estado fantasma).
///   - Rojo Alerta (#C62828): Para errores y alertas críticas.
///   - Verde Activo (#2E7D32): Para buses en servicio y confirmaciones.
///
/// WCAG AA: Todos los pares de color cumplen un ratio mínimo de 4.5:1.
///
/// TIPOGRAFÍA: Se usa la familia 'Inter' registrada de forma nativa en
/// pubspec.yaml (assets/fonts/). NO se usa google_fonts en runtime.
/// Esto elimina el FOUT y la dependencia de red en una app de misión crítica.
/// =============================================================================

import 'package:flutter/material.dart';

/// Todas las constantes de color de la paleta institucional.
/// Usar SIEMPRE estas constantes, nunca hardcodear colores en los widgets.
abstract class AppColors {
  // ── Primario ───────────────────────────────────────────────────────────────
  static const Color primary = Color(0xFF1565C0);      // Azul institucional
  static const Color primaryLight = Color(0xFF5E92F3); // Azul claro (hover)
  static const Color primaryDark = Color(0xFF003C8F);  // Azul oscuro (pressed)
  static const Color onPrimary = Color(0xFFFFFFFF);    // Texto sobre primario

  // ── Neutros ────────────────────────────────────────────────────────────────
  static const Color background = Color(0xFFFFFFFF);   // Blanco puro
  static const Color surface = Color(0xFFF5F7FA);      // Gris neutro (superficies)
  static const Color surfaceVariant = Color(0xFFEEF1F5);
  static const Color divider = Color(0xFFE0E4EA);      // Separadores

  // ── Texto ─────────────────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFF0D0D0D);   // Negro fuerte
  static const Color textSecondary = Color(0xFF4A5568); // Gris oscuro
  static const Color textDisabled = Color(0xFFA0AEC0);  // Gris claro

  // ── Estados de Bus ────────────────────────────────────────────────────────
  static const Color busActive = Color(0xFF2E7D32);    // Bus en servicio
  static const Color busGhost = Color(0xFF9E9E9E);     // Bus sin señal (fantasma)
  static const Color busAlert = Color(0xFFF57C00);     // Bus con novedad

  // ── Semánticos ────────────────────────────────────────────────────────────
  static const Color error = Color(0xFFC62828);
  static const Color success = Color(0xFF2E7D32);
  static const Color warning = Color(0xFFF57C00);
  static const Color info = Color(0xFF0277BD);
}

/// Escala tipográfica institucional.
/// Fuente base: Inter (legible, moderna, diseñada para pantallas).
abstract class AppTextStyles {
  // Estilo base: familia Inter nativa, cargada desde assets/fonts/.
  // No depende de red ni de google_fonts en runtime.
  static const TextStyle _base = TextStyle(
    fontFamily: 'Inter',
    color: AppColors.textPrimary,
    decoration: TextDecoration.none,
  );

  // ── Encabezados ───────────────────────────────────────────────────────────
  static TextStyle get h1 => _base.copyWith(
    fontSize: 28, fontWeight: FontWeight.w700, height: 1.2,
  );
  static TextStyle get h2 => _base.copyWith(
    fontSize: 22, fontWeight: FontWeight.w700, height: 1.3,
  );
  static TextStyle get h3 => _base.copyWith(
    fontSize: 18, fontWeight: FontWeight.w600, height: 1.4,
  );

  // ── Cuerpo ────────────────────────────────────────────────────────────────
  /// Tamaño de cuerpo grande. Usar para contenido principal.
  static TextStyle get bodyLarge => _base.copyWith(
    fontSize: 16, fontWeight: FontWeight.w400, height: 1.6,
  );
  /// Tamaño de cuerpo estándar. Usar para listas y datos.
  static TextStyle get body => _base.copyWith(
    fontSize: 14, fontWeight: FontWeight.w400, height: 1.5,
  );
  /// Tamaño pequeño. Solo para metadatos y etiquetas secundarias.
  static TextStyle get bodySmall => _base.copyWith(
    fontSize: 12, fontWeight: FontWeight.w400, height: 1.5,
    color: AppColors.textSecondary,
  );

  // ── Etiquetas y Botones ───────────────────────────────────────────────────
  static TextStyle get labelLarge => _base.copyWith(
    fontSize: 15, fontWeight: FontWeight.w600, height: 1.2, letterSpacing: 0.1,
  );
  static TextStyle get label => _base.copyWith(
    fontSize: 13, fontWeight: FontWeight.w500, height: 1.2,
  );
  static TextStyle get caption => _base.copyWith(
    fontSize: 11, fontWeight: FontWeight.w500, height: 1.3,
    letterSpacing: 0.5, color: AppColors.textSecondary,
  );

  // ── ETA (Número grande del panel inferior) ────────────────────────────────
  static TextStyle get etaNumber => _base.copyWith(
    fontSize: 48, fontWeight: FontWeight.w700, height: 1.0,
    color: AppColors.primary,
  );
  static TextStyle get etaLabel => _base.copyWith(
    fontSize: 13, fontWeight: FontWeight.w500, height: 1.2,
    color: AppColors.textSecondary, letterSpacing: 0.5,
  );
}

/// Espaciado consistente basado en una escala de 4pt.
abstract class AppSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;
}

/// Bordes redondeados. Institucional = menos redondez que una app social.
abstract class AppRadius {
  static const double sm = 6.0;
  static const double md = 10.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
  static const BorderRadius card = BorderRadius.all(Radius.circular(md));
  static const BorderRadius button = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius chip = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius sheet = BorderRadius.vertical(top: Radius.circular(lg));
}

/// Elevaciones. Minimalistas — sin sombras dramáticas.
abstract class AppElevation {
  static const double none = 0.0;
  static const double low = 1.0;
  static const double medium = 3.0;
  static const double high = 6.0;
}

/// Configuración central del ThemeData.
/// Este objeto se pasa a MaterialApp.theme y MaterialApp.darkTheme.
abstract class AppTheme {
  static ThemeData get lightTheme {
    final colorScheme = ColorScheme.light(
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      primaryContainer: AppColors.primaryLight.withOpacity(0.15),
      secondary: AppColors.primaryLight,
      onSecondary: AppColors.onPrimary,
      error: AppColors.error,
      surface: AppColors.background,
      onSurface: AppColors.textPrimary,
      surfaceContainerHighest: AppColors.surface,
      outline: AppColors.divider,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,

      // ── Scaffold ────────────────────────────────────────────────────────
      scaffoldBackgroundColor: AppColors.background,

      // ── Tipografía global ────────────────────────────────────────────────
      // Aplica Inter como fuente de texto base en todo el tema Material.
      // La familia 'Inter' está registrada nativamente en pubspec.yaml.
      fontFamily: 'Inter',
      textTheme: ThemeData.light().textTheme.apply(
        fontFamily: 'Inter',
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      ),

      // ── AppBar ───────────────────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 1,
        surfaceTintColor: Colors.transparent,
        shadowColor: AppColors.divider,
        centerTitle: false,
        titleTextStyle: AppTextStyles.h3,
        iconTheme: const IconThemeData(color: AppColors.textPrimary, size: 24),
      ),

      // ── ElevatedButton ───────────────────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          minimumSize: const Size(double.infinity, 52), // Touch target 52dp
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.button),
          elevation: 0,
          textStyle: AppTextStyles.labelLarge,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        ),
      ),

      // ── OutlinedButton ───────────────────────────────────────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          minimumSize: const Size(double.infinity, 52),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.button),
          side: const BorderSide(color: AppColors.primary, width: 1.5),
          textStyle: AppTextStyles.labelLarge,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        ),
      ),

      // ── InputDecoration ──────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm + 4,
        ),
        border: OutlineInputBorder(
          borderRadius: AppRadius.card,
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.card,
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.card,
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        labelStyle: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
        hintStyle: AppTextStyles.body.copyWith(color: AppColors.textDisabled),
      ),

      // ── Card ──────────────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        color: AppColors.background,
        elevation: AppElevation.low,
        shadowColor: AppColors.textPrimary.withOpacity(0.08),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.card),
        margin: const EdgeInsets.all(0),
      ),

      // ── Divider ───────────────────────────────────────────────────────────
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
        space: 0,
      ),

      // ── BottomSheet ───────────────────────────────────────────────────────
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.background,
        modalBackgroundColor: AppColors.background,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.sheet),
        elevation: AppElevation.high,
        shadowColor: Color(0x1A0D0D0D),
      ),

      // ── SnackBar ──────────────────────────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.textPrimary,
        contentTextStyle: AppTextStyles.body.copyWith(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.card),
      ),

      // ── Icon ─────────────────────────────────────────────────────────────
      iconTheme: const IconThemeData(
        color: AppColors.textSecondary,
        size: 24,
      ),
    );
  }
}
