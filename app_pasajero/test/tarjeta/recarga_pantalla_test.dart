import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ya_viene_pasajero/core/services/abrir_enlace.dart';
import 'package:ya_viene_pasajero/features/tarjeta/data/tarjeta_guardada.dart';
import 'package:ya_viene_pasajero/features/tarjeta/domain/recarga.dart';
import 'package:ya_viene_pasajero/features/tarjeta/domain/saldo.dart';
import 'package:ya_viene_pasajero/features/tarjeta/domain/tarjeta.dart';
import 'package:ya_viene_pasajero/features/tarjeta/presentation/tarjeta_providers.dart';
import 'package:ya_viene_pasajero/features/tarjeta/presentation/tarjeta_screen.dart';

const _prueba = '12345678';
const _valor = 'AbCdEfGhIjKlMnOpQrSt0123';

class _Saldo implements ProveedorSaldo {
  @override
  bool get simulado => true;

  @override
  Future<ConsultaSaldo> consultar(NumeroTarjeta numero) async =>
      SaldoConsultado(
        valor: 12300,
        consultado: DateTime(2026, 11, 12, 7, 5),
        origen: OrigenSaldo.simulacion,
      );
}

/// La pasarela de mentira: lo que `iniciar` y `consultar` contestan lo
/// manda la prueba.
class _Pasarela implements ProveedorRecarga {
  InicioRecarga inicio = RecargaLista(
    referencia: ReferenciaRecarga.leer(_valor)!,
    pagina: Uri.parse('https://pagos.ejemplo.co/pagar/$_valor'),
  );
  ConsultaRecarga estado = const RecargaPendiente();
  int consultas = 0;

  @override
  bool get simulado => true;

  @override
  PaginasDePago get paginas => const PaginasDePago(hosts: {'pagos.ejemplo.co'});

  @override
  Future<InicioRecarga> iniciar(NumeroTarjeta numero) async => inicio;

  @override
  Future<ConsultaRecarga> consultar(ReferenciaRecarga referencia) async {
    consultas++;
    return estado;
  }
}

void main() {
  late _Pasarela pasarela;
  late List<Uri> abiertas;
  late ProviderContainer contenedor;

  Future<void> abrir(WidgetTester tester) async {
    FlutterSecureStorage.setMockInitialValues(
      {TarjetaGuardada.llave: _prueba},
    );
    SharedPreferences.setMockInitialValues(
      {TarjetaGuardada.marcaInstalacion: true},
    );
    final prefs = await SharedPreferences.getInstance();
    tester.view.physicalSize = const Size(393 * 3, 852 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    pasarela = _Pasarela();
    abiertas = [];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tarjetaGuardadaProvider.overrideWith(
            (ref) async => TarjetaGuardada(
              almacen: const FlutterSecureStorage(),
              prefs: prefs,
            ),
          ),
          proveedorSaldoProvider.overrideWithValue(_Saldo()),
          proveedorRecargaProvider.overrideWithValue(pasarela),
          abrirEnlaceProvider.overrideWithValue((uri) async {
            abiertas.add(uri);
            return true;
          }),
        ],
        child: const MaterialApp(home: TarjetaScreen()),
      ),
    );
    contenedor = ProviderScope.containerOf(
      tester.element(find.byType(TarjetaScreen)),
    );
    await tester.pumpAndSettle();
  }

  Future<void> recargar(WidgetTester tester) async {
    final boton = find.widgetWithText(FilledButton, 'Recargar');
    await tester.ensureVisible(boton);
    await tester.tap(boton);
    await tester.pumpAndSettle();
  }

  Future<void> vuelve(WidgetTester tester, String enlace) async {
    await contenedor.read(recargaProvider.notifier).alVolver(enlace);
    await tester.pumpAndSettle();
  }

  const enlace = 'yaviene://recarga?referencia=$_valor';

  testWidgets('sin recarga en curso ofrece «Recargar» y no abre nada',
      (tester) async {
    await abrir(tester);
    expect(find.widgetWithText(FilledButton, 'Recargar'), findsOneWidget);
    expect(abiertas, isEmpty);
  });

  testWidgets('«Recargar» abre la página del proveedor y queda pendiente',
      (tester) async {
    await abrir(tester);
    await recargar(tester);
    expect(abiertas.single.host, 'pagos.ejemplo.co');
    expect(abiertas.single.toString(), isNot(contains(_prueba)));
    expect(find.text('Esperando tu pago'), findsOneWidget);
    expect(find.text('Comprobar'), findsOneWidget);
  });

  testWidgets('al volver aprobada, lo dice el proveedor', (tester) async {
    await abrir(tester);
    await recargar(tester);
    pasarela.estado = const RecargaAprobada(valor: 20000);
    await vuelve(tester, enlace);
    expect(find.text('Recarga aprobada'), findsOneWidget);
    expect(find.textContaining(r'$20.000'), findsOneWidget);
  });

  testWidgets(
      'el enlace dice aprobada pero el proveedor dice rechazada: '
      'manda el proveedor', (tester) async {
    await abrir(tester);
    await recargar(tester);
    pasarela.estado = const RecargaRechazada();
    await vuelve(tester, '$enlace&estado=aprobada');
    expect(find.text('El pago no se completó'), findsOneWidget);
    expect(find.text('Recarga aprobada'), findsNothing);
  });

  testWidgets('un enlace basura, ajeno o sin recarga en curso no cambia nada',
      (tester) async {
    await abrir(tester);
    await vuelve(tester, '$enlace&estado=aprobada');
    expect(find.widgetWithText(FilledButton, 'Recargar'), findsOneWidget);
    await recargar(tester);
    await vuelve(tester, 'yaviene://recarga?referencia=corta');
    await vuelve(
      tester,
      'yaviene://recarga?referencia=ZZZZZZZZZZZZZZZZZZZZZZZZ',
    );
    await vuelve(tester, 'https://malo.co/?x=1');
    expect(find.text('Esperando tu pago'), findsOneWidget);
    expect(pasarela.consultas, 0);
  });

  testWidgets('un enlace repetido no vuelve a cobrar la misma referencia',
      (tester) async {
    await abrir(tester);
    await recargar(tester);
    pasarela.estado = const RecargaAprobada();
    await vuelve(tester, enlace);
    contenedor.read(recargaProvider.notifier).descartar();
    await tester.pumpAndSettle();
    await vuelve(tester, enlace);
    expect(pasarela.consultas, 1);
    expect(find.text('Recarga aprobada'), findsNothing);
  });

  testWidgets('sin red al volver: se queda y «Comprobar» lo reintenta',
      (tester) async {
    await abrir(tester);
    await recargar(tester);
    pasarela.estado = const RecargaSinRed();
    await vuelve(tester, enlace);
    expect(find.text('Sin internet'), findsWidgets);
    pasarela.estado = const RecargaAprobada();
    await tester.tap(find.text('Comprobar'));
    await tester.pumpAndSettle();
    expect(find.text('Recarga aprobada'), findsOneWidget);
  });

  testWidgets('pendiente se repregunta con «Comprobar»', (tester) async {
    await abrir(tester);
    await recargar(tester);
    pasarela.estado = const RecargaPendiente();
    await tester.tap(find.text('Comprobar'));
    await tester.pumpAndSettle();
    expect(pasarela.consultas, 1);
    expect(find.text('Esperando tu pago'), findsOneWidget);
  });

  testWidgets('referencia desconocida para el proveedor', (tester) async {
    await abrir(tester);
    await recargar(tester);
    pasarela.estado = const RecargaDesconocida();
    await vuelve(tester, enlace);
    expect(find.text('No encontramos esta recarga'), findsOneWidget);
  });

  testWidgets('sin red al empezar: no se abre nada', (tester) async {
    await abrir(tester);
    pasarela.inicio = const InicioSinRed();
    await recargar(tester);
    expect(abiertas, isEmpty);
    expect(find.text('Sin internet'), findsWidgets);
  });

  testWidgets('el sistema no abre la página: se dice y se puede reintentar',
      (tester) async {
    await abrir(tester);
    pasarela.inicio = const InicioNoDisponible();
    await recargar(tester);
    expect(find.text('No pudimos abrir el pago'), findsOneWidget);
    expect(find.text('Intentar de nuevo'), findsOneWidget);
  });

  testWidgets('quitar la tarjeta cierra la recarga en curso', (tester) async {
    await abrir(tester);
    await recargar(tester);
    await contenedor.read(tarjetaProvider.notifier).quitar();
    await tester.pumpAndSettle();
    expect(contenedor.read(recargaProvider), isNull);
    pasarela.estado = const RecargaAprobada();
    await contenedor.read(recargaProvider.notifier).alVolver(enlace);
    expect(pasarela.consultas, 0);
  });
}
