@Tags(['goldens'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import 'package:ya_viene_pasajero/features/tarjeta/data/tarjeta_guardada.dart';
import 'package:ya_viene_pasajero/features/tarjeta/domain/recarga.dart';
import 'package:ya_viene_pasajero/features/tarjeta/domain/saldo.dart';
import 'package:ya_viene_pasajero/features/tarjeta/domain/tarjeta.dart';
import 'package:ya_viene_pasajero/features/tarjeta/presentation/tarjeta_providers.dart';
import 'package:ya_viene_pasajero/features/tarjeta/presentation/tarjeta_screen.dart';

import 'golden_harness.dart';

class _Fijo implements ProveedorSaldo {
  const _Fijo(this.respuesta);
  final ConsultaSaldo respuesta;
  @override
  bool get simulado => true;
  @override
  Future<ConsultaSaldo> consultar(NumeroTarjeta numero) async => respuesta;
}

/// Un estado de la recarga fijo: lo que el proveedor contestó, sin red.
class _RecargaFija extends RecargaNotifier {
  _RecargaFija(this.fija);
  final ConsultaRecarga fija;
  @override
  ConsultaRecarga? build() => fija;
}

/// El saldo de la tarjeta SIBUS (D22) en cada uno de sus estados, con la
/// etiqueta «Simulación» arriba mientras el saldo sea inventado (D8).
void main() {
  Future<void> abrir(
    WidgetTester tester, {
    String? guardada,
    ConsultaSaldo? respuesta,
    ConsultaRecarga? recarga,
  }) async {
    fijarPantalla(tester);
    FlutterSecureStorage.setMockInitialValues(
      // Número de prueba evidente, no es de ninguna tarjeta.
      {if (guardada != null) TarjetaGuardada.llave: guardada},
    );
    SharedPreferences.setMockInitialValues(
      {TarjetaGuardada.marcaInstalacion: true},
    );
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tarjetaGuardadaProvider.overrideWith(
            (ref) async => TarjetaGuardada(
              almacen: const FlutterSecureStorage(),
              prefs: prefs,
            ),
          ),
          if (recarga != null)
            recargaProvider.overrideWith(() => _RecargaFija(recarga)),
          proveedorSaldoProvider.overrideWithValue(
            _Fijo(
              respuesta ??
                  SaldoConsultado(
                    valor: 12300,
                    consultado: DateTime(2026, 11, 12, 7, 5),
                    origen: OrigenSaldo.simulacion,
                  ),
            ),
          ),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          locale: const Locale('es', 'CO'),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: const TarjetaScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Tarjeta, sin tarjeta', (tester) async {
    await abrir(tester);
    await expectLater(find.byType(TarjetaScreen),
        matchesGoldenFile('goldens/tarjeta_sin_tarjeta.png'));
  });

  testWidgets('Tarjeta, saldo', (tester) async {
    await abrir(tester, guardada: '12345678');
    await expectLater(find.byType(TarjetaScreen),
        matchesGoldenFile('goldens/tarjeta_saldo.png'));
  });

  testWidgets('Tarjeta, sin red', (tester) async {
    await abrir(tester, guardada: '12345678', respuesta: const SaldoSinRed());
    await expectLater(find.byType(TarjetaScreen),
        matchesGoldenFile('goldens/tarjeta_sin_red.png'));
  });

  testWidgets('Tarjeta, no encontrada', (tester) async {
    await abrir(tester,
        guardada: '12345678', respuesta: const TarjetaNoEncontrada());
    await expectLater(find.byType(TarjetaScreen),
        matchesGoldenFile('goldens/tarjeta_no_encontrada.png'));
  });

  testWidgets('Tarjeta, no disponible', (tester) async {
    await abrir(tester,
        guardada: '12345678', respuesta: const SaldoNoDisponible());
    await expectLater(find.byType(TarjetaScreen),
        matchesGoldenFile('goldens/tarjeta_no_disponible.png'));
  });

  testWidgets('Recarga, pendiente', (tester) async {
    await abrir(tester,
        guardada: '12345678', recarga: const RecargaPendiente());
    await expectLater(find.byType(TarjetaScreen),
        matchesGoldenFile('goldens/recarga_pendiente.png'));
  });

  testWidgets('Recarga, aprobada', (tester) async {
    await abrir(tester,
        guardada: '12345678', recarga: const RecargaAprobada(valor: 20000));
    await expectLater(find.byType(TarjetaScreen),
        matchesGoldenFile('goldens/recarga_aprobada.png'));
  });

  testWidgets('Recarga, rechazada', (tester) async {
    await abrir(tester,
        guardada: '12345678', recarga: const RecargaRechazada());
    await expectLater(find.byType(TarjetaScreen),
        matchesGoldenFile('goldens/recarga_rechazada.png'));
  });

  testWidgets('Recarga, desconocida', (tester) async {
    await abrir(tester,
        guardada: '12345678', recarga: const RecargaDesconocida());
    await expectLater(find.byType(TarjetaScreen),
        matchesGoldenFile('goldens/recarga_desconocida.png'));
  });

  testWidgets('Recarga, sin_red', (tester) async {
    await abrir(tester, guardada: '12345678', recarga: const RecargaSinRed());
    await expectLater(find.byType(TarjetaScreen),
        matchesGoldenFile('goldens/recarga_sin_red.png'));
  });

  testWidgets('Recarga, no_abierta', (tester) async {
    await abrir(tester,
        guardada: '12345678', recarga: const RecargaNoAbierta());
    await expectLater(find.byType(TarjetaScreen),
        matchesGoldenFile('goldens/recarga_no_abierta.png'));
  });
}
