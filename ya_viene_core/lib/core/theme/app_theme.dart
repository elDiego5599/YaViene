import 'package:flutter/material.dart';

abstract class AppColors {
  static const Color primaryDeep = Color(0xFF14274E);
  static const Color primary = Color(0xFF00A859);
  static const Color primaryTint = Color(0xFFE6F7F0);

  /// F4: variante de [primary] con contraste AA (4.5:1) en texto chico o
  /// texto blanco sobre fondo verde — [primary] solo, ~3.1:1, no alcanza.
  static const Color primaryAccessible = Color(0xFF047857);

  // ── Identidad "movilidad urbana editorial" (Fase 1) ───────────────────
  /// Arena cálida: superficies de tarjetas y estados vacíos.
  static const Color arena = Color(0xFFFAF6F0);

  /// Coral suave: excepciones importantes (bus sin señal, avisos críticos).
  static const Color coral = Color(0xFFE86A5E);
  static const Color coralLight = Color(0xFFFBE7E4);

  /// Azul eléctrico: reservado a la ruta activa del usuario y su métrica.
  static const Color electricBlue = Color(0xFF2563EB);

  /// Tinta profunda: fondos "hero" de splash, login, onboarding y el drawer.
  static const Color ink = Color(0xFF0B1628);

  static const Color background = Color(0xFFF8F9FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFF1F5F9);
  static const Color divider = Color(0xFFE5E7EB);

  /// El filo que separa dos superficies claras. Más tenue que [divider] y
  /// tibio, no gris azulado: sobre [arena] un gris frío se ve como una
  /// raya sucia, y este desaparece salvo justo donde tiene que estar.
  static const Color hairline = Color(0x1414274E);

  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textDisabled = Color(0xFF94A3B8);

  /// Rojo del bus en vivo sobre el mapa. Comparte el valor de [coral] —
  /// es el rojo cálido de la marca — pero vive aparte a propósito: [coral]
  /// significa "excepción" (bus sin señal, aviso crítico) y esto significa
  /// "bus activo y reportando". Si algún día se separan de color, se cambia
  /// aquí sin tocar la semántica de las excepciones.
  static const Color busActive = Color(0xFFE86A5E);

  static const Color busGhost = Color(0xFF94A3B8);
  static const Color error = Color(0xFFDC2626);
  static const Color errorLight = Color(0xFFFEE2E2);
  static const Color success = Color(0xFF059669);
  static const Color successLight = Color(0xFFD1FAE5);

  /// Ámbar: advertencia recuperable, no crítica (GPS sin fix, sin buses
  /// cerca por ahora). Distinto de [coral]: eso es para excepciones ya
  /// confirmadas (bus sin señal), esto es "reintenta o espera".
  static const Color warning = Color(0xFFD97706);
  static const Color warningLight = Color(0xFFFEF3C7);
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
  // La fuente vive en el bundle de cada app (sección `flutter.fonts`), NO se
  // descarga por red en runtime: sin FOUT ni dependencia de Google Fonts.
  static const TextStyle _base = TextStyle(
    fontFamily: 'PlusJakartaSans',
    color: AppColors.textPrimary,
    decoration: TextDecoration.none,
    letterSpacing: -0.3,
  );

  static final TextStyle h1 = _base.copyWith(
    fontSize: 28.0,
    fontWeight: FontWeight.w800,
    height: 1.15,
    letterSpacing: -0.6,
  );

  static final TextStyle h2 = _base.copyWith(
    fontSize: 22.0,
    fontWeight: FontWeight.w800,
    height: 1.2,
    letterSpacing: -0.4,
  );

  static final TextStyle h3 = _base.copyWith(
    fontSize: 18.0,
    fontWeight: FontWeight.w700,
    height: 1.3,
    letterSpacing: -0.3,
  );

  static final TextStyle bodyLarge = _base.copyWith(
    fontSize: 16.0,
    fontWeight: FontWeight.w500,
    height: 1.5,
  );

  static final TextStyle body = _base.copyWith(
    fontSize: 14.0,
    fontWeight: FontWeight.w500,
    height: 1.5,
  );

  static final TextStyle labelLarge = _base.copyWith(
    fontSize: 16.0,
    fontWeight: FontWeight.w700,
    height: 1.2,
  );

  static final TextStyle label = _base.copyWith(
    fontSize: 13.0,
    fontWeight: FontWeight.w600,
    color: AppColors.textSecondary,
    height: 1.2,
  );

  static final TextStyle etaNumber = _base.copyWith(
    fontSize: 84.0,
    fontWeight: FontWeight.w200,
    height: 0.9,
    letterSpacing: -3.0,
    color: AppColors.primaryDeep,
  );
}

abstract class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      // V5: arena es el fondo general de la app; background queda solo para
      // superficies que de verdad necesitan un gris neutro (p. ej. el mapa).
      scaffoldBackgroundColor: AppColors.arena,
      // Fuente del bundle de la app (Plus Jakarta Sans), como AppTextStyles.
      fontFamily: 'PlusJakartaSans',
      // Firma de movimiento: cualquier InkWell/ListTile suelto que no defina
      // su propio splash hereda este verde tenue en vez del gris de fábrica.
      splashColor: AppColors.primary.withValues(alpha: 0.10),
      highlightColor: AppColors.primary.withValues(alpha: 0.05),

      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.arena,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        titleTextStyle: AppTextStyles.h3,
        iconTheme: const IconThemeData(color: AppColors.primaryDeep, size: 24),
      ),

      // F11: sin esto, un TextButton sin minimumSize propio cae en los 40dp
      // de fábrica de Material — por debajo del tap target accesible de 44dp.
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(0, 44),
          tapTargetSize: MaterialTapTargetSize.padded,
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryDeep,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.pill)),
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
          borderSide:
              const BorderSide(color: AppColors.primaryDeep, width: 2.0),
        ),
        labelStyle: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
        hintStyle: AppTextStyles.body.copyWith(color: AppColors.textDisabled),
      ),

      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.card)),
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
        shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(AppRadius.sheet))),
        elevation: 0,
      ),
    );
  }
}
