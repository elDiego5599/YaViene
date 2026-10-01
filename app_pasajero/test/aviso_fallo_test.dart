import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import 'package:ya_viene_pasajero/core/providers/red_provider.dart';
import 'package:ya_viene_pasajero/core/widgets/aviso_fallo.dart';

/// El aviso de una carga que falló en el selector.
///
/// El dueño lo encontró así (2026-09-30): sin empresas, tocar «Reintentar»
/// no hacía nada visible. Riverpod deja el error puesto mientras vuelve a
/// pedir y sin red el intento falla en milisegundos: la pantalla no se
/// movía. Y todo era «Error al cargar empresas», con o sin wifi.
void main() {
  Future<StreamController<bool>> montar(
    WidgetTester tester, {
    required Object error,
    required Future<void> Function() onReintentar,
    bool compacto = false,
    bool red = true,
  }) async {
    final redes = StreamController<bool>();
    addTearDown(redes.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          hayRedProvider.overrideWith((ref) => redes.stream),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 360,
                height: compacto ? 78 : 400,
                child: AvisoFallo(
                  error: error,
                  que: 'las empresas',
                  onReintentar: onReintentar,
                  compacto: compacto,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    redes.add(red);
    await tester.pump();
    return redes;
  }

  group('dice la causa', () {
    testWidgets('sin red: revisa tus datos', (tester) async {
      await montar(
        tester,
        error: const SocketException('Failed host lookup'),
        onReintentar: () async {},
      );
      expect(find.text('Sin conexión'), findsOneWidget);
      expect(
        find.text('No cargaron las empresas. Revisa tus datos o el wifi.'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.wifi_off_outlined), findsOneWidget);
    });

    testWidgets('el servidor contestó mal: no es tu conexión', (tester) async {
      await montar(
        tester,
        error: const RespuestaFallida(502),
        onReintentar: () async {},
      );
      expect(find.text('Falla en el servidor'), findsOneWidget);
      expect(
        find.textContaining('No es tu conexión'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.cloud_off_outlined), findsOneWidget);
    });

    testWidgets('nadie contestó a tiempo', (tester) async {
      await montar(
        tester,
        error: TimeoutException('8 s'),
        onReintentar: () async {},
      );
      expect(find.text('El servidor no responde'), findsOneWidget);
    });

    testWidgets('si el teléfono no tiene red, manda sobre el error',
        (tester) async {
      // Sin wifi el túnel tampoco contesta, y su error parece del servidor.
      await montar(
        tester,
        error: const RespuestaFallida(502),
        onReintentar: () async {},
        red: false,
      );
      expect(find.text('Sin conexión'), findsOneWidget);
      expect(find.text('Falla en el servidor'), findsNothing);
    });
  });

  group('Reintentar se ve trabajar', () {
    testWidgets(
        'aunque el intento falle al instante, la espera se ve '
        'y la tarjeta se sacude', (tester) async {
      var intentos = 0;
      await montar(
        tester,
        error: const SocketException('sin red'),
        onReintentar: () async {
          intentos++;
          throw const SocketException('sin red');
        },
      );

      await tester.tap(find.text('Reintentar'));
      await tester.pump();
      expect(intentos, 1);
      expect(find.text('Reintentando…'), findsOneWidget);
      expect(find.byType(IndicadorCarga), findsOneWidget);

      // A medio pulso sigue intentando, aunque el error ya volvió.
      await tester.pump(AppMotion.pulso ~/ 2);
      expect(find.text('Reintentando…'), findsOneWidget);
      // Un segundo toque no lanza otro intento.
      await tester.tap(find.text('Reintentando…'));
      expect(intentos, 1);

      await tester.pump(AppMotion.pulso ~/ 2);
      await tester.pump(AppMotion.entrada ~/ 4);
      // Vuelve el botón, y la tarjeta se está sacudiendo.
      expect(find.text('Reintentar'), findsOneWidget);
      final corrida = tester
          .widgetList<Transform>(find.descendant(
            of: find.byType(AvisoFallo),
            matching: find.byType(Transform),
          ))
          .first
          .transform
          .getTranslation()
          .x;
      expect(corrida, isNot(0));
      await tester.pumpAndSettle();
    });

    testWidgets('con movimiento reducido no se sacude', (tester) async {
      await tester.pumpWidget(const SizedBox());
      final redes = StreamController<bool>();
      addTearDown(redes.close);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [hayRedProvider.overrideWith((ref) => redes.stream)],
          child: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: MaterialApp(
              home: Scaffold(
                body: AvisoFallo(
                  error: const SocketException('sin red'),
                  que: 'las empresas',
                  onReintentar: () async =>
                      throw const SocketException('sin red'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Reintentar'));
      await tester.pump(AppMotion.pulso);
      await tester.pump(AppMotion.entrada ~/ 4);
      for (final t in tester.widgetList<Transform>(find.descendant(
        of: find.byType(AvisoFallo),
        matching: find.byType(Transform),
      ))) {
        expect(t.transform.getTranslation().x, 0);
      }
      await tester.pumpAndSettle();
    });

    testWidgets('en la fila: toda la fila reintenta y dice que lo hace',
        (tester) async {
      var intentos = 0;
      await montar(
        tester,
        compacto: true,
        error: const SocketException('sin red'),
        onReintentar: () async => intentos++,
      );
      expect(find.text('Sin conexión'), findsOneWidget);
      expect(find.text('No cargaron las empresas'), findsOneWidget);

      await tester.tap(find.text('Sin conexión'));
      await tester.pump();
      expect(intentos, 1);
      expect(find.text('Reintentando…'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.text('No cargaron las empresas'), findsOneWidget);
    });
  });

  testWidgets('cuando vuelve la red, reintenta solo', (tester) async {
    var intentos = 0;
    final redes = await montar(
      tester,
      error: const SocketException('sin red'),
      onReintentar: () async => intentos++,
      red: false,
    );
    expect(intentos, 0);

    redes.add(true);
    await tester.pump();
    await tester.pump();
    expect(intentos, 1);
    expect(find.text('Reintentando…'), findsOneWidget);
    await tester.pumpAndSettle();
  });
}
