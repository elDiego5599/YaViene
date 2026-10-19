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

  /// El borde de arriba de una hoja que sube sobre fondo oscuro: medio tono
  /// por encima de [arena], para que la hoja tenga labio propio en vez de
  /// una línea de borde muerta. Se funde en [arena] en el primer 20 %.
  static const Color arenaAlta = Color(0xFFFFFDF8);

  /// Coral suave: excepciones importantes (bus sin señal, avisos críticos).
  static const Color coral = Color(0xFFE86A5E);

  /// El coral cuando lo que se pinta es un glifo o una letra. Hermano de
  /// [primaryAccessible] y [warningAccessible]; ver el porqué allí.
  static const Color coralAccessible = Color(0xFFC0392B);
  static const Color coralLight = Color(0xFFFBE7E4);

  /// Azul eléctrico: la ruta activa del usuario y su métrica.
  static const Color electricBlue = Color(0xFF2563EB);

  /// El fondo de los botones llenos. Antes era [primaryDeep], que el
  /// dueño vio apagado; el eléctrico le pareció feo y eligió este
  /// intermedio (2026-09-28), solo para botones: íconos, texto, bordes de
  /// foco y la cifra grande siguen en [primaryDeep]. Blanco encima da
  /// 7,1:1 (test/contraste_test.dart).
  static const Color acento = Color(0xFF1E56A8);

  /// El blanco de la placa del bus: el de las placas del servicio
  /// público, las que lleva el bus que llega, así la placa de la pantalla
  /// se coteja de un vistazo con la de la calle (dueño, 2026-09-30; antes
  /// fue el amarillo de los particulares). Solo para la placa, con letra
  /// [textPrimary] encima y un filo del mismo color que la recorta de la
  /// arena y de la tarjeta blanca, contra las que el blanco no se separa
  /// (ya_viene_core/test/contraste_test.dart).
  static const Color placa = Color(0xFFFFFFFF);

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

  /// Texto sobre [ink]. Blanco puro sobre azul muy oscuro vibra; este
  /// gris casi blanco se apoya sin zumbar.
  static const Color textOnInk = Color(0xFFF8FAFC);

  /// El rojo destructivo sobre [ink]: [error] (#DC2626) se hunde en el
  /// fondo oscuro y deja de leerse como aviso.
  static const Color errorOnInk = Color(0xFFFF6B6B);

  static const Color textPrimary = Color(0xFF0F172A);

  /// El escalón que faltaba entre [textPrimary] y [textSecondary]: el
  /// párrafo de una tarjeta clara, donde [textSecondary] se aclara de más
  /// (4.8:1 sobre blanco) y [textPrimary] pesa como un título. Este da
  /// 7.5:1 y se lee como texto, no como rótulo.
  ///
  /// Estaba escrito a mano cuatro veces —la guía del mapa y la hoja del
  /// bus— con el mismo número y sin nombre.
  static const Color textBody = Color(0xFF475569);

  /// El rótulo y el pie: lo que acompaña sin ser el texto principal.
  ///
  /// Era #64748B, medio punto por debajo de la raya en los tres fondos
  /// claros de la app: 4,4:1 sobre la arena de las hojas, 4,3:1 sobre el
  /// gris de los campos de texto. Este es el mismo gris azulado medio
  /// tono más oscuro, y pasa el 4,5:1 en los tres —arena, blanco y
  /// [surfaceMuted]— sin acercarse a [textBody], que pesa como párrafo.
  static const Color textSecondary = Color(0xFF5E6B82);
  static const Color textDisabled = Color(0xFF94A3B8);

  static const Color busGhost = Color(0xFF94A3B8);
  static const Color error = Color(0xFFDC2626);
  static const Color errorLight = Color(0xFFFEE2E2);
  static const Color success = Color(0xFF059669);
  static const Color successLight = Color(0xFFD1FAE5);

  /// Ámbar: advertencia recuperable, no crítica (GPS sin fix, sin buses
  /// cerca por ahora). Distinto de [coral]: eso es para excepciones ya
  /// confirmadas (bus sin señal), esto es "reintenta o espera".
  static const Color warning = Color(0xFFD97706);

  /// El ámbar cuando lo que se pinta es un glifo o una letra y no un
  /// relleno: [warning] da 2,9:1 sobre la arena y 2,9:1 sobre su propio
  /// [warningLight], por debajo del 3:1 que pide la norma incluso para
  /// iconos. Este da 5,0:1 sobre la arena, casi el mismo número que
  /// [primaryAccessible] (5,1:1) y que [coralAccessible] (5,1:1): los
  /// tres semáforos pesan igual y ninguno grita más que otro.
  static const Color warningAccessible = Color(0xFFA85206);
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
  /// La placa del bus en la hoja: una lámina con las esquinas apenas
  /// romas, como la de la calle. Con [sm] (8) sobre sus 21 de alto se
  /// volvía píldora y dejaba de parecer placa.
  static const double xs = 6.0;
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

  // ── La escala ────────────────────────────────────────────────────────
  //
  // Diez roles y nada más. Antes había veinte tamaños de letra, catorce
  // letter-spacings sueltos y w800 en treinta y cuatro sitios: eso no es
  // una jerarquía, es el mismo grito a distintos volúmenes.
  //
  // Tres reglas para no volver ahí:
  //  · El espaciado no se elige, se deduce del tamaño. Cuanto más grande
  //    la letra, más se cierra; a partir del cuerpo ya no se toca.
  //  · w800 es la excepción, no la norma: solo el nombre de la app, el
  //    título que encabeza una pantalla y el botón principal —`marca`,
  //    `display` y `boton`, y ninguno más—. Los cuerpos van en w400 y w500,
  //    que es para lo que estamos cargando esos dos pesos en el bundle.
  //  · Quien necesite algo que no está aquí está pidiendo un rol nuevo,
  //    no un `TextStyle` suelto.

  /// El nombre de la app, escrito.
  ///
  /// No es un título: es la mitad tipográfica del logo, y va siempre junto
  /// al dibujo —arranque, entrada y bienvenida, y en ningún sitio más—.
  /// Está aquí, y no suelto en el widget que lo pinta, porque cada pantalla
  /// lo escribía a su propio tamaño (36, 34) sin que ninguna tuviera un
  /// motivo: el dibujo sí releva a la pantalla de arranque nativa y tiene
  /// que medir lo que mide allí, pero esa pantalla no escribe nada.
  static final TextStyle marca = _base.copyWith(
    fontSize: 36.0,
    fontWeight: FontWeight.w800,
    height: 1.0,
    letterSpacing: -1.2,
  );

  /// El número que la app existe para dar: los metros que faltan.
  ///
  /// Es el único sitio donde el peso más fino tiene sentido, porque es el
  /// único texto lo bastante grande para sostenerlo.
  static final TextStyle dato = _base.copyWith(
    fontSize: 64.0,
    fontWeight: FontWeight.w200,
    height: 0.9,
    letterSpacing: -2.0,
    color: AppColors.primaryDeep,
  );

  /// Lo primero que se lee de una pantalla. Uno por pantalla.
  static final TextStyle display = _base.copyWith(
    fontSize: 28.0,
    fontWeight: FontWeight.w800,
    height: 1.15,
    letterSpacing: -0.6,
  );

  /// Encabeza un bloque dentro de la pantalla.
  static final TextStyle titulo = _base.copyWith(
    fontSize: 22.0,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: -0.4,
  );

  /// Encabeza una fila o una tarjeta: el nombre de una ruta, el de una
  /// empresa, el de una opción del menú.
  static final TextStyle subtitulo = _base.copyWith(
    fontSize: 18.0,
    fontWeight: FontWeight.w700,
    height: 1.3,
    letterSpacing: -0.3,
  );

  /// El cuerpo cuando tiene que pesar: el texto de un botón, el dato de
  /// una fila. Mismo tamaño que [cuerpo] a propósito — lo que cambia es el
  /// peso, no la medida, y así las dos cosas siguen alineadas.
  static final TextStyle cuerpoFuerte = _base.copyWith(
    fontSize: 15.0,
    fontWeight: FontWeight.w600,
    height: 1.4,
    letterSpacing: -0.2,
  );

  /// Texto para leer. La medida de lectura de la app.
  static final TextStyle cuerpo = _base.copyWith(
    fontSize: 15.0,
    fontWeight: FontWeight.w400,
    height: 1.5,
    letterSpacing: -0.2,
  );

  /// Lo que dice un botón que hace algo de verdad.
  ///
  /// Es el tercer y último sitio donde vive w800. Está aquí porque si no,
  /// cada botón principal de la app lo escribe a mano —y ya lo hacía, en
  /// cinco pantallas, con el mismo 16/w800 copiado— o lo pide con un
  /// `copyWith(fontWeight: w800)` sobre [cuerpoFuerte], que es un rol
  /// suelto con otro nombre. El color no se fija: lo pone quien lo pinte,
  /// que unas veces es blanco sobre tinta y otras al revés.
  static final TextStyle boton = _base.copyWith(
    fontSize: 16.0,
    fontWeight: FontWeight.w800,
    height: 1.2,
    letterSpacing: -0.2,
  );

  /// Nombra algo que está al lado: la unidad del número, el estado de una
  /// píldora, el encabezado de una sección del menú.
  static final TextStyle etiqueta = _base.copyWith(
    fontSize: 13.0,
    fontWeight: FontWeight.w600,
    height: 1.2,
    letterSpacing: -0.1,
    color: AppColors.textSecondary,
  );

  /// La letra chica: la aclaración que se lee después, si acaso.
  static final TextStyle pie = _base.copyWith(
    fontSize: 12.0,
    fontWeight: FontWeight.w500,
    height: 1.3,
    letterSpacing: 0,
    color: AppColors.textSecondary,
  );

  /// Los ocho roles vestidos de Material, para lo que no pasa por
  /// nosotros: diálogos, `SnackBar`, `ListTile`, el texto que se escribe
  /// en un campo. El nombre de Material a la izquierda es solo el enchufe;
  /// la decisión es siempre el rol de la derecha.
  static TextTheme get textTheme => TextTheme(
        displayLarge: dato,
        displayMedium: display,
        displaySmall: display,
        headlineLarge: display,
        headlineMedium: titulo,
        headlineSmall: titulo,
        titleLarge: titulo,
        titleMedium: subtitulo,
        titleSmall: cuerpoFuerte,
        bodyLarge: cuerpo,
        bodyMedium: cuerpo,
        bodySmall: pie,
        labelLarge: boton,
        labelMedium: etiqueta,
        labelSmall: pie,
      );

  // ── Nombres viejos ───────────────────────────────────────────────────
  //
  // La Fase 3 los retiró de `app_pasajero` y del tema: ahí ya no queda
  // ninguno. Siguen aquí los que todavía sostienen a alguien: `body` y
  // `label` en el desplegable de `shared/`, `labelLarge` y `label` en el
  // chip, y `etaNumber` en el pasajero.
  //
  // `h1`, `h2`, `h3` y `bodyLarge` se fueron con la app de demostración que
  // era su único lector.

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
      // El fondo general es blanco y lo blanco de encima se despega con
      // sombra (dueño, 2026-10-16; antes arena, V5). background queda solo
      // para superficies que de verdad necesitan un gris neutro (el mapa).
      scaffoldBackgroundColor: AppColors.surface,
      // Fuente del bundle de la app (Plus Jakarta Sans), como AppTextStyles.
      fontFamily: 'PlusJakartaSans',
      // El tema fijaba la fuente pero no la escala, así que
      // `Theme.of(context).textTheme` devolvía la de Material en tamaños
      // que no son los nuestros. Todo lo que no trae estilo propio —un
      // diálogo, un `SnackBar`, un `ListTile`, el texto que se escribe en
      // un campo, y sobre todo el `DefaultTextStyle` de cualquier `Text`
      // pelado— caía ahí. Ahora cae en la escala.
      textTheme: AppTextStyles.textTheme,
      // Firma de movimiento: cualquier InkWell/ListTile suelto que no defina
      // su propio splash hereda este verde tenue en vez del gris de fábrica.
      splashColor: AppColors.primary.withValues(alpha: 0.10),
      highlightColor: AppColors.primary.withValues(alpha: 0.05),

      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        // El título de la barra manda sobre las filas de la pantalla que
        // encabeza, así que va un escalón por encima de ellas: las filas de
        // Avisos son `subtitulo` y estaban empatadas con él. Es además el
        // tamaño que Material le da por defecto a una barra.
        titleTextStyle: AppTextStyles.titulo,
        iconTheme: const IconThemeData(color: AppColors.primaryDeep, size: 24),
      ),

      // F11: sin esto, un TextButton sin minimumSize propio cae en los 40dp
      // de fábrica de Material — por debajo del tap target accesible de 44dp.
      //
      // El color tampoco estaba puesto, así que un TextButton sin `styleFrom`
      // propio —el «Reintentar» del banner de mapa caído, por ejemplo— salía
      // en el morado de fábrica de Material 3, que no es un color de esta app.
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primaryDeep,
          minimumSize: const Size(0, 44),
          tapTargetSize: MaterialTapTargetSize.padded,
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.acento,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.pill)),
          elevation: 0,
          textStyle: AppTextStyles.boton,
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
        labelStyle: AppTextStyles.cuerpo.copyWith(
          color: AppColors.textSecondary,
        ),
        hintStyle: AppTextStyles.cuerpo.copyWith(
          color: AppColors.textSecondary,
        ),
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

      // Los avisos de abajo —«activa las notificaciones», «ya tienes un
      // aviso para ese bus»— salían en el gris oscuro de fábrica, pegados al
      // borde y con el botón en morado. Ahora flotan con el tinta del menú,
      // redondeados como las píldoras del mapa, con el texto de la app y la
      // acción en el verde de la marca, que sobre tinta llega de sobra a
      // 4.5:1.
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.ink,
        elevation: 0,
        insetPadding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.md,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        contentTextStyle: AppTextStyles.cuerpo.copyWith(
          color: AppColors.textOnInk,
        ),
        actionTextColor: AppColors.primary,
      ),

      // Por si algún diálogo se abre sin pasar por la ventana propia de la
      // app: al menos cae en su superficie, su radio y su tipografía.
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        titleTextStyle: AppTextStyles.subtitulo,
        contentTextStyle: AppTextStyles.cuerpo.copyWith(
          color: AppColors.textBody,
        ),
      ),

      // El globo de ayuda que sale al dejar el dedo sobre un botón de icono
      // («Volver», «Cerrar menú») era el gris de fábrica con esquinas de 4.
      // Va en la tinta del menú con su texto claro, como los avisos, y con
      // el radio chico del sistema: es una etiqueta, no una tarjeta.
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.ink,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: AppSpacing.sm,
        ),
        textStyle: AppTextStyles.etiqueta.copyWith(
          color: AppColors.textOnInk,
        ),
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
