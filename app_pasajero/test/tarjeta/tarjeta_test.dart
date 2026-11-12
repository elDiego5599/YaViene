import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ya_viene_pasajero/features/tarjeta/data/tarjeta_guardada.dart';
import 'package:ya_viene_pasajero/features/tarjeta/domain/saldo.dart';
import 'package:ya_viene_pasajero/features/tarjeta/domain/tarjeta.dart';

// Números de prueba evidentes: ninguno es de una tarjeta real.
const _prueba = '12345678';

void main() {
  group('NumeroTarjeta.leer', () {
    test('acepta solo dígitos y quita los espacios con que se agrupa', () {
      final n = NumeroTarjeta.leer(' 1234 5678 ');
      expect(n, isA<NumeroValido>());
      expect((n as NumeroValido).numero.digitos, _prueba);
    });

    test('rechaza vacío, letras, signos y largos fuera del tope', () {
      expect(
          NumeroTarjeta.leer('   '), const NumeroInvalido(FalloNumero.vacio));
      expect(NumeroTarjeta.leer('1234a678'),
          const NumeroInvalido(FalloNumero.soloDigitos));
      expect(NumeroTarjeta.leer('1234-5678'),
          const NumeroInvalido(FalloNumero.soloDigitos));
      // Los dígitos de otros alfabetos tampoco: solo 0 a 9 ASCII.
      expect(NumeroTarjeta.leer('١٢٣٤٥٦٧٨'),
          const NumeroInvalido(FalloNumero.soloDigitos));
      expect(NumeroTarjeta.leer('1' * (NumeroTarjeta.minimo - 1)),
          const NumeroInvalido(FalloNumero.muyCorto));
      expect(NumeroTarjeta.leer('1' * (NumeroTarjeta.maximo + 1)),
          const NumeroInvalido(FalloNumero.muyLargo));
      expect(
          NumeroTarjeta.leer('1' * NumeroTarjeta.maximo), isA<NumeroValido>());
    });

    test('una entrada enorme no se recorre entera', () {
      expect(NumeroTarjeta.leer('9' * 100000),
          const NumeroInvalido(FalloNumero.muyLargo));
    });
  });

  group('NumeroTarjeta no deja ver el número', () {
    final n = (NumeroTarjeta.leer('9876543210') as NumeroValido).numero;

    test('en pantalla solo los últimos 4', () {
      expect(n.ultimos4, '3210');
      expect(n.enmascarado, '•••• 3210');
    });

    test('toString no lo trae, ni entero ni en parte', () {
      expect(n.toString(), isNot(contains('3210')));
      expect(n.toString(), isNot(contains('98765')));
      expect('$n', 'NumeroTarjeta(oculto)');
    });

    test('las consultas y sus textos no lo traen', () {
      final consultas = <ConsultaSaldo>[
        SaldoConsultado(
            valor: 12000,
            consultado: DateTime(2026, 11, 11, 8, 30),
            origen: OrigenSaldo.simulacion),
        const SaldoSinRed(),
        const TarjetaNoEncontrada(),
        const SaldoNoDisponible(),
      ];
      for (final c in consultas) {
        expect('$c', isNot(contains('3210')));
      }
    });
  });

  group('SaldoSimulado', () {
    final hora = DateTime(2026, 11, 11, 7, 45);
    SaldoSimulado simulado({bool red = true}) => SaldoSimulado(
          hayRed: () async => red,
          reloj: () => hora,
          espera: Duration.zero,
        );
    NumeroTarjeta n(String s) => (NumeroTarjeta.leer(s) as NumeroValido).numero;

    test('da un saldo fijo por número, en pesos redondos y con su hora',
        () async {
      final a = await simulado().consultar(n(_prueba));
      final b = await simulado().consultar(n(_prueba));
      expect(a, isA<SaldoConsultado>());
      a as SaldoConsultado;
      expect(a.valor, (b as SaldoConsultado).valor);
      expect(a.valor % 100, 0);
      expect(a.valor, inInclusiveRange(0, 100000));
      expect(a.consultado, hora);
      expect(a.origen, OrigenSaldo.simulacion);
    });

    test('los números de prueba llevan a no encontrada y no disponible',
        () async {
      expect(await simulado().consultar(n(SaldoSimulado.pruebaNoEncontrada)),
          const TarjetaNoEncontrada());
      expect(await simulado().consultar(n(SaldoSimulado.pruebaNoDisponible)),
          const SaldoNoDisponible());
    });

    test('sin red lo dice, no inventa un saldo', () async {
      expect(await simulado(red: false).consultar(n(_prueba)),
          const SaldoSinRed());
    });

    test('es simulado', () => expect(simulado().simulado, isTrue));
  });

  group('TarjetaGuardada', () {
    late SharedPreferences prefs;

    Future<TarjetaGuardada> abrir({
      Map<String, String> llavero = const {},
      Map<String, Object> preferencias = const {},
    }) async {
      FlutterSecureStorage.setMockInitialValues(Map.of(llavero));
      SharedPreferences.setMockInitialValues(Map.of(preferencias));
      prefs = await SharedPreferences.getInstance();
      return TarjetaGuardada(
          almacen: const FlutterSecureStorage(), prefs: prefs);
    }

    test('guarda, lee y quita el número del almacén seguro', () async {
      final t = await abrir();
      expect(await t.leer(), isNull);
      await t.guardar((NumeroTarjeta.leer(_prueba) as NumeroValido).numero);
      expect((await t.leer())?.digitos, _prueba);
      await t.quitar();
      expect(await t.leer(), isNull);
    });

    test('el número no va a SharedPreferences', () async {
      final t = await abrir();
      await t.guardar((NumeroTarjeta.leer(_prueba) as NumeroValido).numero);
      for (final k in prefs.getKeys()) {
        expect('${prefs.get(k)}', isNot(contains(_prueba)));
      }
    });

    test('tras reinstalar (sin la marca) borra lo que quedó en el Llavero',
        () async {
      // iOS conserva el Llavero al desinstalar; SharedPreferences no.
      final t = await abrir(llavero: {TarjetaGuardada.llave: _prueba});
      expect(await t.leer(), isNull);
      expect(prefs.getBool(TarjetaGuardada.marcaInstalacion), isTrue);
      expect(
          await const FlutterSecureStorage().read(key: TarjetaGuardada.llave),
          isNull);
    });

    test('con la marca puesta conserva lo guardado', () async {
      final t = await abrir(
        llavero: {TarjetaGuardada.llave: _prueba},
        preferencias: {TarjetaGuardada.marcaInstalacion: true},
      );
      expect((await t.leer())?.digitos, _prueba);
    });

    test('lo guardado que no es un número válido se borra', () async {
      final t = await abrir(
        llavero: {TarjetaGuardada.llave: '<script>'},
        preferencias: {TarjetaGuardada.marcaInstalacion: true},
      );
      expect(await t.leer(), isNull);
      expect(
          await const FlutterSecureStorage().read(key: TarjetaGuardada.llave),
          isNull);
    });
  });
}
