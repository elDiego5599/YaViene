import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/providers/red_provider.dart';
import '../data/tarjeta_guardada.dart';
import '../domain/saldo.dart';
import '../domain/tarjeta.dart';

/// El Llavero o el Keystore del teléfono, con la marca de instalación.
final tarjetaGuardadaProvider = FutureProvider<TarjetaGuardada>(
  (ref) async => TarjetaGuardada(
    almacen: TarjetaGuardada.opcionesDelSistema,
    prefs: await SharedPreferences.getInstance(),
  ),
);

/// Quién responde el saldo. Mientras no haya convenio con el AMB es la
/// simulación (D22), y la pantalla lo dice con su etiqueta.
final proveedorSaldoProvider = Provider<ProveedorSaldo>(
  (ref) => SaldoSimulado(hayRed: () => ref.read(hayRedProvider.future)),
);

/// La tarjeta guardada en este teléfono, o `null` si no hay ninguna.
final tarjetaProvider =
    AsyncNotifierProvider<TarjetaNotifier, NumeroTarjeta?>(TarjetaNotifier.new);

class TarjetaNotifier extends AsyncNotifier<NumeroTarjeta?> {
  @override
  Future<NumeroTarjeta?> build() async =>
      (await ref.watch(tarjetaGuardadaProvider.future)).leer();

  Future<void> guardar(NumeroTarjeta numero) async {
    await (await ref.read(tarjetaGuardadaProvider.future)).guardar(numero);
    state = AsyncData(numero);
  }

  Future<void> quitar() async {
    await (await ref.read(tarjetaGuardadaProvider.future)).quitar();
    state = const AsyncData(null);
  }
}

/// El saldo de la tarjeta guardada; `null` sin tarjeta. Se vuelve a pedir
/// con `ref.invalidate(saldoProvider)` y se olvida al salir de la pantalla.
final saldoProvider = FutureProvider.autoDispose<ConsultaSaldo?>((ref) async {
  final tarjeta = await ref.watch(tarjetaProvider.future);
  if (tarjeta == null) return null;
  return ref.watch(proveedorSaldoProvider).consultar(tarjeta);
});
