import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

/// El contraste de la paleta, en los pares que de verdad se pintan.
///
/// Un color se elige mirándolo en la pantalla del portátil, con la luz de
/// la casa. El bus se espera en la calle, al sol de Barranquilla, y ahí un
/// verde bonito de 2,9:1 deja de leerse. Estos números son los de la WCAG
/// 2.2, que es la vara con la que mide Apple y con la que mediría una
/// entidad pública:
///
/// * 4,5:1 para texto normal (menos de 24, o menos de 19 en negrita).
/// * 3:1 para texto grande y para cualquier glifo o control que diga algo.
///
/// La prueba no vigila la paleta entera: vigila los pares que existen en
/// la app, color sobre el fondo concreto donde va.

/// Luminancia relativa, tal como la define la WCAG.
double _luminancia(Color c) {
  double canal(double v) =>
      v <= 0.04045 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * canal(c.r) + 0.7152 * canal(c.g) + 0.0722 * canal(c.b);
}

/// Razón de contraste entre dos colores opacos.
double contraste(Color a, Color b) {
  final la = _luminancia(a);
  final lb = _luminancia(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void esperaAlMenos(Color frente, Color fondo, double minimo, String donde) {
  final valor = contraste(frente, fondo);
  expect(
    valor,
    greaterThanOrEqualTo(minimo),
    reason: '$donde da ${valor.toStringAsFixed(2)}:1 y necesita '
        '$minimo:1.',
  );
}

void main() {
  group('el semáforo de la distancia sobre la arena de la hoja', () {
    // El número de 64 en peso 200 es el trazo más fino de la app y lo
    // único que la app existe para decir.
    test('los tres pasan de texto normal', () {
      esperaAlMenos(AppColors.primaryAccessible, AppColors.arena, 4.5,
          'el verde de «lejos»');
      esperaAlMenos(AppColors.warningAccessible, AppColors.arena, 4.5,
          'el ámbar de «acercándose»');
      esperaAlMenos(AppColors.coralAccessible, AppColors.arena, 4.5,
          'el coral de «ya casi»');
    });

    test('los tres pesan lo mismo', () {
      // Si uno contrasta bastante más que otro, la misma cifra se lee más
      // urgente por el color y no por la distancia.
      final valores = [
        contraste(AppColors.primaryAccessible, AppColors.arena),
        contraste(AppColors.warningAccessible, AppColors.arena),
        contraste(AppColors.coralAccessible, AppColors.arena),
      ];
      final rango =
          valores.reduce(math.max) - valores.reduce(math.min);
      expect(rango, lessThan(0.5));
    });

    test('el estado sin dato también se lee', () {
      esperaAlMenos(AppColors.textSecondary, AppColors.arena, 3.0,
          '«Calculando», que va en 28 negrita');
    });
  });

  group('el glifo dentro de su medallón', () {
    test('cada color va sobre su propio tinte', () {
      esperaAlMenos(AppColors.primaryAccessible, AppColors.primaryTint, 3.0,
          'el bus verde del medallón');
      esperaAlMenos(AppColors.warningAccessible, AppColors.warningLight, 3.0,
          'la campana ámbar del medallón');
      esperaAlMenos(AppColors.coralAccessible, AppColors.coralLight, 3.0,
          'la ubicación coral del medallón');
      esperaAlMenos(AppColors.error, AppColors.errorLight, 3.0,
          'la ubicación bloqueada del medallón');
    });
  });

  group('el texto chico de color sobre superficie clara', () {
    test('la pista ámbar de una fila del selector', () {
      esperaAlMenos(AppColors.warningAccessible, AppColors.surface, 4.5,
          'la pista de 12 en ámbar');
    });
  });

  group('los grises de texto', () {
    test('sobre las dos superficies claras', () {
      for (final fondo in [AppColors.surface, AppColors.arena]) {
        esperaAlMenos(AppColors.textPrimary, fondo, 4.5, 'el texto primario');
        esperaAlMenos(AppColors.textBody, fondo, 4.5, 'el cuerpo');
        esperaAlMenos(AppColors.textSecondary, fondo, 4.5, 'el secundario');
      }
    });
  });

  group('el texto sobre la tinta oscura', () {
    test('la bienvenida y el menú', () {
      esperaAlMenos(AppColors.textOnInk, AppColors.ink, 4.5, 'el texto');
      esperaAlMenos(AppColors.errorOnInk, AppColors.ink, 4.5, 'el destructivo');
    });

    test('la acción de los avisos de abajo', () {
      // El «Ajustes» del aviso de notificaciones va en el verde de la marca
      // sobre la tinta del aviso.
      esperaAlMenos(AppColors.primary, AppColors.ink, 4.5, 'la acción');
    });

    test('el tema pone los avisos de abajo sobre la tinta', () {
      final tema = AppTheme.lightTheme.snackBarTheme;
      expect(tema.backgroundColor, AppColors.ink);
      expect(tema.actionTextColor, AppColors.primary);
      expect(tema.behavior, SnackBarBehavior.floating);
    });
  });

  group('los botones con letra blanca', () {
    test('el par de los CTAs verdes y el del bloqueado', () {
      // El verde de marca a secas da 3,1:1 con blanco y no alcanza: los
      // CTAs van sobre la variante accesible, y el bloqueado sobre el
      // mismo gris con el que el panel pinta «Ocultar».
      esperaAlMenos(Colors.white, AppColors.primaryAccessible, 4.5,
          'el CTA verde');
      esperaAlMenos(Colors.white, AppColors.textSecondary, 4.5,
          'el CTA bloqueado');
    });
  });

  group('el acento azul (#2563EB, prueba del dueño)', () {
    // La tinta #14274E en botones, íconos y bordes de foco se veía apagada;
    // el dueño eligió el azul eléctrico (la opción E) para que la app se
    // vea viva. Este es el par con el que se lee.
    test('es el azul eléctrico', () {
      expect(AppColors.acento, AppColors.electricBlue);
      expect(AppColors.acento, const Color(0xFF2563EB));
    });

    test('el tema lo pone en los controles y en el dato', () {
      final tema = AppTheme.lightTheme;
      final estados = <WidgetState>{};
      expect(
          tema.elevatedButtonTheme.style!.backgroundColor!.resolve(estados),
          AppColors.acento);
      expect(tema.textButtonTheme.style!.foregroundColor!.resolve(estados),
          AppColors.acento);
      final foco = tema.inputDecorationTheme.focusedBorder!
          as OutlineInputBorder;
      expect(foco.borderSide.color, AppColors.acento);
      expect(tema.appBarTheme.iconTheme!.color, AppColors.acento);
      expect(AppTextStyles.dato.color, AppColors.acento);
      expect(AppTextStyles.etaNumber.color, AppColors.acento);
    });

    test('la letra blanca del botón y el azul como texto se leen', () {
      esperaAlMenos(Colors.white, AppColors.acento, 4.5, 'el botón azul');
      for (final fondo in [
        AppColors.surface,
        AppColors.arena,
        AppColors.background,
        AppColors.surfaceMuted,
      ]) {
        esperaAlMenos(AppColors.acento, fondo, 4.5, 'el azul como texto');
      }
    });
  });

  group('la pista de los campos', () {
    test('se lee sobre el relleno de fondo', () {
      final hint = AppTheme.lightTheme.inputDecorationTheme.hintStyle;
      expect(hint?.color, isNotNull);
      esperaAlMenos(hint!.color!, AppColors.background, 4.5, 'la pista');
    });
  });

  group('los grises apagados sobre la tinta del drawer', () {
    test('el gris pálido es el que lee ahí, no el gris de papel', () {
      // El drawer es fondo oscuro: aquí `textSecondary` bajaría a 3,4:1 y
      // el que vale es `textDisabled`. Si algún día se «arregla» este
      // gris por el de papel, esta prueba avisa.
      esperaAlMenos(
          AppColors.textDisabled, AppColors.ink, 4.5, '«RUTA ACTIVA»');
    });
  });
}
