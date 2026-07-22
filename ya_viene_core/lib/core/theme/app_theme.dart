import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract class AppColors {
  // ── Paleta KOHO Style ──────────────────────────────────────────────────────
  static const Color primaryDeep = Color(0xFF14274E); // Fondo azul marino oscuro profundo
  static const Color primary = Color(0xFF00A859);     // Verde esmeralda vibrante
  static const Color primaryTint = Color(0xFFE6F7F0);
  
  // ── Fondos ───────────────────────────────────────────────────────────────
  static const Color background = Color(0xFFF8F9FA);  // Blanco crudo/gris perla muy claro para contraste
  static const Color surface = Color(0xFFFFFFFF);     // Tarjetas de Blanco puro
  static const Color surfaceMuted = Color(0xFFF1F5F9);
  static const Color divider = Color(0xFFE5E7EB);
  
  // ── Tipografía ───────────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFF0F172A); // Casi negro, excelente contraste
  static const Color textSecondary = Color(0xFF64748B); // Gris medio
  static const Color textDisabled = Color(0xFF94A3B8);
  
  // ── Estados ─────────────────────────────────────────────────────────────
  static const Color busGhost = Color(0xFF94A3B8); 
  static const Color error = Color(0xFFDC2626);
  static const Color errorLight = Color(0xFFFEE2E2);
  static const Color success = Color(0xFF059669);
  static const Color successLight = Color(0xFFD1FAE5);
}

abstract class AppSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;
}

abstract class AppRadius {
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double card = 24.0;
  static const double sheet = 32.0;
  static const double pill = 999.0;
}

abstract class AppShadows {
  static final List<BoxShadow> floating = [
    BoxShadow(
      color: const Color(0xFF14274E).withValues(alpha: 0.08),
      blurRadius: 32,
      spreadRadius: 0,
      offset: const Offset(0, 16),
    ),
    BoxShadow(
      color: const Color(0xFF14274E).withValues(alpha: 0.04),
      blurRadius: 10,
      spreadRadius: -2,
      offset: const Offset(0, 4),
    ),
  ];
  
  static final List<BoxShadow> soft = [
    BoxShadow(
      color: const Color(0xFF0F172A).withValues(alpha: 0.05),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];
}

abstract class AppTextStyles {
  static final TextStyle _base = GoogleFonts.plusJakartaSans(
    color: AppColors.textPrimary,
    decoration: TextDecoration.none,
    letterSpacing: -0.3,
  );

  static final TextStyle h1 = _base.copyWith(
    fontSize: 28.0, fontWeight: FontWeight.w800, height: 1.15, letterSpacing: -0.6,
  );
  
  static final TextStyle h2 = _base.copyWith(
    fontSize: 22.0, fontWeight: FontWeight.w800, height: 1.2, letterSpacing: -0.4,
  );

  static final TextStyle h3 = _base.copyWith(
    fontSize: 18.0, fontWeight: FontWeight.w700, height: 1.3, letterSpacing: -0.3,
  );

  static final TextStyle bodyLarge = _base.copyWith(
    fontSize: 16.0, fontWeight: FontWeight.w500, height: 1.5,
  );

  static final TextStyle body = _base.copyWith(
    fontSize: 14.0, fontWeight: FontWeight.w500, height: 1.5,
  );

  static final TextStyle labelLarge = _base.copyWith(
    fontSize: 16.0, fontWeight: FontWeight.w700, height: 1.2,
  );

  static final TextStyle label = _base.copyWith(
    fontSize: 13.0, fontWeight: FontWeight.w600, color: AppColors.textSecondary, height: 1.2,
  );
  
  static final TextStyle etaNumber = _base.copyWith(
    fontSize: 84.0, fontWeight: FontWeight.w200, height: 0.9, letterSpacing: -3.0, color: AppColors.primaryDeep,
  );
}

abstract class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.background,
      textTheme: GoogleFonts.plusJakartaSansTextTheme(),

      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        titleTextStyle: AppTextStyles.h3,
        iconTheme: const IconThemeData(color: AppColors.primaryDeep, size: 24),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryDeep,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.pill)),
          elevation: 0,
          textStyle: AppTextStyles.labelLarge,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.background,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: const BorderSide(color: AppColors.divider, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: const BorderSide(color: AppColors.divider, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: const BorderSide(color: AppColors.primaryDeep, width: 2.0),
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
    );
  }
}
