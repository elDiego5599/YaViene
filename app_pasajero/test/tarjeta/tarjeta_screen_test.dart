import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import 'package:ya_viene_pasajero/core/widgets/dialogo.dart';
import 'package:ya_viene_pasajero/features/tarjeta/data/tarjeta_guardada.dart';
import 'package:ya_viene_pasajero/features/tarjeta/domain/saldo.dart';
import 'package:ya_viene_pasajero/features/tarjeta/domain/tarjeta.dart';
import 'package:ya_viene_pasajero/features/tarjeta/presentation/tarjeta_providers.dart';
import 'package:ya_viene_pasajero/features/tarjeta/presentation/tarjeta_screen.dart';

import '../helpers/contraste.dart';

/// Un número de prueba evidente: no es de ninguna tarjeta real.
const _prueba = '12345678';

/// Responde siempre lo mismo y cuenta cuántas veces le piden. Con `demora`
/// la respuesta tarda, para ver la espera.
class _ProveedorFijo implements ProveedorSaldo {
  _ProveedorFijo(this.respuesta, {this.simulado = true});

  ConsultaSaldo respuesta;
  Duration demora = Duration.zero;
  int consultas = 0;

  @override
  final bool simulado;

  @override
  Future<ConsultaSaldo> consultar(NumeroTarjeta numero) async {
    consultas++;
    if (demora > Duration.zero) await Future<void>.delayed(demora);
    return respuesta;
  }
}

final _saldo = SaldoConsultado(
  valor: 12300,
  consultado: DateTime(2026, 11, 12, 7, 5),
  origen: OrigenSaldo.simulacion,
);

void main() {
  late _ProveedorFijo proveedor;

  Future<void> abrir(
    WidgetTester tester, {
    String? guardada,
    ConsultaSaldo? respuesta,
    bool simulado = true,
  }) async {
    FlutterSecureStorage.setMockInitialValues(
      {if (guardada != null) TarjetaGuardada.llave: guardada},
    );
    SharedPreferences.setMockInitialValues(
      {TarjetaGuardada.marcaInstalacion: true},
    );
    final prefs = await SharedPreferences.getInstance();
    // Un teléfono (solo teléfonos, regla 6): el iPhone 16 de 393 × 852 pt.
    tester.view.physicalSize = const Size(393 * 3, 852 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    proveedor = _ProveedorFijo(respuesta ?? _saldo, simulado: simulado);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tarjetaGuardadaProvider.overrideWith(
            (ref) async => TarjetaGuardada(
              almacen: const FlutterSecureStorage(),
              prefs: prefs,
            ),
          ),
          proveedorSaldoProvider.overrideWithValue(proveedor),
        ],
        child: const MaterialApp(home: TarjetaScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Ni en el texto pintado ni en lo que oye VoiceOver.
  void exigeNumeroOculto(WidgetTester tester) {
    expect(find.textContaining(_prueba), findsNothing);
    final arbol = tester
        .getSemantics(find.byType(Scaffold))
        .toStringDeep(childOrder: DebugSemanticsDumpOrder.traversalOrder);
    // El árbol sí llega a la tarjeta (lo enmascarado está), y el número no.
    expect(arbol, contains('5678'));
    expect(arbol, isNot(contains(_prueba)));
  }

  group('sin tarjeta', () {
    testWidgets('pide el número y dice que se guarda solo aquí',
        (tester) async {
      final semantica = tester.ensureSemantics();
      await abrir(tester);
      expect(find.text('Número de la tarjeta'), findsOneWidget);
      expect(find.text('Guardar tarjeta'), findsOneWidget);
      expect(find.textContaining('solo en este teléfono'), findsWidgets);
      expect(proveedor.consultas, 0);
      semantica.dispose();
    });

    testWidgets('dice qué le falta al número antes de guardarlo',
        (tester) async {
      await abrir(tester);
      Future<void> probar(String texto, String mensaje) async {
        await tester.enterText(find.byType(TextField), texto);
        await tester.tap(find.text('Guardar tarjeta'));
        await tester.pumpAndSettle();
        expect(find.text(mensaje), findsOneWidget, reason: texto);
      }

      await probar('', 'Escribe el número de la tarjeta.');
      await probar('1234', 'El número tiene al menos 8 cifras.');
      expect(proveedor.consultas, 0);
    });

    testWidgets('el campo solo deja escribir cifras y hasta 20',
        (tester) async {
      await abrir(tester);
      await tester.enterText(find.byType(TextField), '12ab-34');
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '1234',
      );
      await tester.enterText(find.byType(TextField), '1' * 30);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '1' * NumeroTarjeta.maximo,
      );
    });

    testWidgets('guardar enseña la tarjeta enmascarada y su saldo',
        (tester) async {
      final semantica = tester.ensureSemantics();
      await abrir(tester);
      await tester.enterText(find.byType(TextField), _prueba);
      await tester.tap(find.text('Guardar tarjeta'));
      await tester.pumpAndSettle();
      expect(find.text('•••• 5678'), findsOneWidget);
      expect(find.text(r'$12.300'), findsOneWidget);
      exigeNumeroOculto(tester);
      expect(
        await const FlutterSecureStorage().read(key: TarjetaGuardada.llave),
        _prueba,
      );
      semantica.dispose();
    });
  });

  group('con tarjeta', () {
    testWidgets('saldo, hora de la consulta y número enmascarado',
        (tester) async {
      final semantica = tester.ensureSemantics();
      await abrir(tester, guardada: _prueba);
      expect(find.text('•••• 5678'), findsOneWidget);
      expect(find.text(r'$12.300'), findsOneWidget);
      expect(find.text('Consultado a las 7:05 a. m.'), findsOneWidget);
      exigeNumeroOculto(tester);
      semantica.dispose();
    });

    testWidgets('consultar de nuevo vuelve a preguntar al proveedor',
        (tester) async {
      await abrir(tester, guardada: _prueba);
      expect(proveedor.consultas, 1);
      await tester.tap(find.text('Consultar de nuevo'));
      await tester.pumpAndSettle();
      expect(proveedor.consultas, 2);
    });

    testWidgets('mientras consulta lo dice', (tester) async {
      await abrir(tester, guardada: _prueba);
      proveedor.demora = const Duration(seconds: 1);
      await tester.tap(find.text('Consultar de nuevo'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.bySemanticsLabel('Consultando el saldo'), findsOneWidget);
      // El saldo de antes se queda mientras llega el nuevo.
      expect(find.text('\$12.300'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Consultando el saldo'), findsNothing);
    });

    testWidgets('sin red', (tester) async {
      await abrir(tester, guardada: _prueba, respuesta: const SaldoSinRed());
      expect(find.text('Sin internet'), findsOneWidget);
      expect(find.text('Consultar de nuevo'), findsOneWidget);
      expect(find.text('•••• 5678'), findsOneWidget);
    });

    testWidgets('tarjeta no encontrada deja cambiar el número', (tester) async {
      await abrir(
        tester,
        guardada: _prueba,
        respuesta: const TarjetaNoEncontrada(),
      );
      expect(find.text('No encontramos esta tarjeta'), findsOneWidget);
      await tester.tap(find.text('Cambiar el número'));
      await tester.pumpAndSettle();
      expect(find.text('Número de la tarjeta'), findsOneWidget);
    });

    testWidgets('saldo no disponible no culpa al pasajero', (tester) async {
      await abrir(
        tester,
        guardada: _prueba,
        respuesta: const SaldoNoDisponible(),
      );
      expect(find.text('El saldo no está disponible ahora'), findsOneWidget);
      expect(find.textContaining('validador azul'), findsOneWidget);
      expect(find.text('Consultar de nuevo'), findsOneWidget);
    });

    testWidgets('quitar la tarjeta pide confirmación y la borra',
        (tester) async {
      await abrir(tester, guardada: _prueba);
      await tester.ensureVisible(find.text('Quitar tarjeta'));
      await tester.tap(find.text('Quitar tarjeta'));
      await tester.pumpAndSettle();
      expect(find.byType(Dialogo), findsOneWidget);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(find.text('•••• 5678'), findsOneWidget);

      await tester.tap(find.text('Quitar tarjeta'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Quitar'));
      await tester.pumpAndSettle();
      expect(find.text('Número de la tarjeta'), findsOneWidget);
      expect(
        await const FlutterSecureStorage().read(key: TarjetaGuardada.llave),
        isNull,
      );
    });
  });

  group('simulación', () {
    testWidgets('la etiqueta se ve en todos los estados mientras sea simulada',
        (tester) async {
      await abrir(tester);
      expect(find.text('Simulación'), findsOneWidget);
      await abrir(tester, guardada: _prueba);
      expect(find.text('Simulación'), findsOneWidget);
    });

    testWidgets('con un proveedor real no hay etiqueta', (tester) async {
      await abrir(tester, guardada: _prueba, simulado: false);
      expect(find.text('Simulación'), findsNothing);
    });

    testWidgets('la etiqueta se lee bien sobre su fondo', (tester) async {
      await abrir(tester);
      final etiqueta = find.text('Simulación');
      exigeContraste(
        contraste(
            letraDe(tester, etiqueta), fondoDelContenedor(tester, etiqueta)),
        4.5,
        'la etiqueta Simulación',
      );
    });
  });

  testWidgets('la cifra del saldo y su tarjeta pasan AA', (tester) async {
    await abrir(tester, guardada: _prueba);
    exigeContraste(
      contraste(letraDe(tester, find.text(r'$12.300')), AppColors.surface),
      4.5,
      'la cifra del saldo',
    );
    exigeContraste(
      contraste(letraDe(tester, find.text('•••• 5678')), AppColors.primaryDeep),
      4.5,
      'el número enmascarado sobre la tarjeta',
    );
  });
}
