import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../config.dart';
import '../../../core/providers/red_provider.dart';
import '../../../core/services/abrir_enlace.dart';
import '../../../core/services/bus_notification_service.dart';
import '../data/recarga_en_curso.dart';
import '../data/recarga_simulada.dart';
import '../data/servicio_recarga.dart';
import '../data/tarjeta_guardada.dart';
import '../domain/recarga.dart';
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
    // Sin tarjeta no hay recarga que seguir.
    await ref.read(recargaProvider.notifier).olvidar();
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

/// Quién procesa la recarga (D23). Hoy la pasarela simulada; la pantalla lo
/// dice con la etiqueta «Simulación». Ya Viene nunca cobra.
final proveedorRecargaProvider = Provider<ProveedorRecarga>(
  (ref) => RecargaSimulada(
    base: Uri.parse(AppConfig.recargaSimuladaUrl),
    hayRed: () => ref.read(hayRedProvider.future),
  ),
);

final servicioRecargaProvider = FutureProvider<ServicioRecarga>((ref) async {
  return ServicioRecarga(
    proveedor: ref.watch(proveedorRecargaProvider),
    enCurso: RecargaEnCurso(await SharedPreferences.getInstance()),
    abrir: ref.watch(abrirEnlaceProvider),
    registrar: (mensaje) => debugPrint(mensaje),
  );
});

/// Cómo va la recarga, o `null` si no hay ninguna a la vista. Lo que dice
/// el enlace de regreso nunca llega aquí: solo lo que contesta el proveedor.
/// Los enlaces de regreso de la pasarela. Aparte para que las pruebas pongan
/// los suyos sin pasar por el canal nativo.
final enlacesDeRecargaProvider =
    Provider<Stream<String>>((ref) => BusNotificationService.recargasVueltas);

final recargaProvider =
    NotifierProvider<RecargaNotifier, ConsultaRecarga?>(RecargaNotifier.new);

class RecargaNotifier extends Notifier<ConsultaRecarga?> {
  @override
  ConsultaRecarga? build() {
    final enlaces = ref.watch(enlacesDeRecargaProvider).listen(alVolver);
    // Si el pasajero vuelve a mano (sin el enlace), se pregunta igual.
    final ciclo = AppLifecycleListener(onResume: reanudar);
    ref.onDispose(() {
      unawaited(enlaces.cancel());
      ciclo.dispose();
    });
    return null;
  }

  Future<ServicioRecarga> get _servicio =>
      ref.read(servicioRecargaProvider.future);

  /// Abre el canal del proveedor. Mientras el pasajero paga fuera, queda
  /// «pendiente».
  Future<void> recargar(NumeroTarjeta numero) async {
    state = await (await _servicio).iniciar(numero);
  }

  /// El pasajero vuelve por `yaviene://recarga?...`. Un enlace que no es de
  /// la recarga en curso no cambia nada.
  Future<void> alVolver(String enlace) async {
    final resultado = await (await _servicio).alVolver(enlace);
    if (resultado != null) state = resultado;
  }

  /// Pregunta de nuevo por la recarga en curso: al volver la app al frente o
  /// con «Comprobar».
  Future<void> reanudar() async {
    final resultado = await (await _servicio).reanudar();
    if (resultado != null) state = resultado;
  }

  /// «Comprobar» tras un «sin red»: si ya no hay nada en curso (el fallo fue
  /// al empezar), se vuelve a ofrecer «Recargar» en vez de quedarse mudo.
  Future<void> comprobar() async {
    final servicio = await _servicio;
    if (!servicio.hayEnCurso) {
      state = null;
      return;
    }
    await reanudar();
  }

  /// El pasajero cierra el resultado (aprobada, desconocida).
  void descartar() => state = null;

  Future<void> olvidar() async {
    await (await _servicio).olvidar();
    state = null;
  }
}
