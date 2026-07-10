/// =============================================================================
/// SISTEMA DE DISEÑO PREMIUM — APP THEME
///
/// Paleta institucional de "Ya Viene" (Estándar NuBank/Rappi):
///   - Cero negros puros. Cero blancos puros para superficies amplias.
///   - Radios amplios y sombras suaves (difusas).
/// =============================================================================

import 'package:flutter/material.dart';

/// Todas las constantes de color de la paleta institucional Premium.
abstract class AppColors {
  // ── Paleta Base Premium ──────────────────────────────────────────────────
  static const Color primary = Color(0xFF1565C0); // Azul institucional fuerte
  static const Color primaryLight = Color(0xFFE3F2FD); // Fondo sutil para chips/estados
  
  static const Color background = Color(0xFFF8F9FC); // Blanco cálido/grisáceo
  static const Color surface = Color(0xFFFFFFFF);    // Blanco puro solo para Cards flotantes
  static const Color divider = Color(0xFFE5E7EB);
  
  static const Color textPrimary = Color(0xFF1A1D26);   // Azul marino/gris muy oscuro
  static const Color textSecondary = Color(0xFF6B7280); // Gris neutro claro
  static const Color textDisabled = Color(0xFF9CA3AF);
  
  // ── Estados ─────────────────────────────────────────────────────────────
  static const Color busGhost = Color(0xFF9CA3AF); 
  static const Color error = Color(0xFFEF4444);    // Rojo alerta (suave)
  static const Color errorLight = Color(0xFFFEE2E2); 
  static const Color success = Color(0xFF10B981);  // Verde activo vibrante
  static const Color successLight = Color(0xFFD1FAE5);
}

/// Espaciados del sistema
abstract class AppSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;
}

/// Radios de borde Premium
abstract class AppRadius {
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;   // Botones y tarjetas pequeñas
  static const double card = 24.0;
  static const double sheet = 28.0; // Bottom sheets
  static const double pill = 999.0;
}

/// Sombras Premium (Elevación Suave y Difusa)
abstract class AppShadows {
  static final List<BoxShadow> soft = [
    BoxShadow(
      color: Colors.black.withOpacity(0.04),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];
  static final List<BoxShadow> floating = [
    BoxShadow(
      color: Colors.black.withOpacity(0.08),
      blurRadius: 32,
      spreadRadius: 0,
      offset: const Offset(0, 12),
    ),
  ];
}

/// Escala tipográfica institucional.
abstract class AppTextStyles {
  static const TextStyle _base = TextStyle(
    fontFamily: 'Inter',
    color: AppColors.textPrimary,
    decoration: TextDecoration.none,
  );

  static final TextStyle h1 = _base.copyWith(
    fontSize: 24.0, fontWeight: FontWeight.w700, height: 1.2,
  );
  
  static final TextStyle h2 = _base.copyWith(
    fontSize: 20.0, fontWeight: FontWeight.w600, height: 1.3,
  );

  static final TextStyle h3 = _base.copyWith(
    fontSize: 16.0, fontWeight: FontWeight.w600, height: 1.4,
  );

  static final TextStyle bodyLarge = _base.copyWith(
    fontSize: 16.0, fontWeight: FontWeight.w400, height: 1.5,
  );

  static final TextStyle body = _base.copyWith(
    fontSize: 14.0, fontWeight: FontWeight.w400, height: 1.5,
  );

  static final TextStyle labelLarge = _base.copyWith(
    fontSize: 15.0, fontWeight: FontWeight.w600, height: 1.2,
  );

  static final TextStyle label = _base.copyWith(
    fontSize: 12.0, fontWeight: FontWeight.w500, color: AppColors.textSecondary, height: 1.2,
  );
  
  static final TextStyle etaNumber = _base.copyWith(
    fontSize: 48.0, fontWeight: FontWeight.w300, height: 1.0, letterSpacing: -1.5, color: AppColors.primary,
  );
}

/// Configuración central del ThemeData.
abstract class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: 'Inter',
      
      textTheme: ThemeData.light().textTheme.apply(
        fontFamily: 'Inter',
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        titleTextStyle: AppTextStyles.h3,
        iconTheme: const IconThemeData(color: AppColors.textPrimary, size: 24),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
          elevation: 0,
          textStyle: AppTextStyles.labelLarge,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: const BorderSide(color: Colors.transparent),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: const BorderSide(color: Colors.transparent),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        labelStyle: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
        hintStyle: AppTextStyles.body.copyWith(color: AppColors.textDisabled),
      ),

      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
        margin: EdgeInsets.zero,
      ),

      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
        space: 0,
      ),

      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        modalBackgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.sheet))),
        elevation: 0,
      ),

      iconTheme: const IconThemeData(
        color: AppColors.textSecondary,
        size: 24,
      ),
    );
  }
}
