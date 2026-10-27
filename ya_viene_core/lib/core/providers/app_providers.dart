import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../models/company.dart';
import '../models/route_info.dart';
import '../network/backend_resolver.dart';
import '../network/fallo_red.dart';

/// La dirección del backend la pone la app que usa este paquete, no el
/// paquete. Antes cada lado leía por su cuenta el `--dart-define` y no
/// coincidían: el pasajero fallaba de golpe si faltaba la variable, y esto
/// se iba en silencio a localhost, así que en un release sin la variable la
/// app decía "no se pudo cargar" sin decir por qué. Sin `override` esto
/// lanza, que es la forma de que el olvido se vea en el primer arranque.
///
/// La URL puede cambiar con la app abierta ([BackendUrl.reResolver]): quien
/// la mira con `watch` pasa solo al backend nuevo, sin reiniciar.
final backendUrlProvider = NotifierProvider<BackendUrl, String>(
  () => throw UnimplementedError(
    'Falta backendUrlProvider: la app debe sobrescribirlo en su '
    'ProviderScope con la URL del backend.',
  ),
);

/// La URL del backend con la que habla la app, y entre cuáles puede cambiar.
class BackendUrl extends Notifier<String> {
  /// [inicial] es la que eligió el arranque; [principal] y [respaldo], entre
  /// las que se vuelve a elegir. [sonda] existe para las pruebas.
  BackendUrl(
    this._inicial, {
    required this.principal,
    this.respaldo = '',
    Future<bool> Function(String url, Duration espera)? sonda,
  }) : _sonda = sonda;

  /// Una URL que no cambia nunca: sin respaldo, [reResolver] no tiene a
  /// dónde ir.
  BackendUrl.fija(String url) : this(url, principal: url);

  final String _inicial;
  final String principal;
  final String respaldo;
  final Future<bool> Function(String url, Duration espera)? _sonda;

  /// Cada cuánto, en el respaldo, se pregunta si la principal ya contesta.
  /// Antes la app se quedaba en la flota simulada del respaldo toda la sesión
  /// aunque ngrok reviviera (dueño, 2026-10-26).
  static const Duration vueltaCada = Duration(seconds: 30);

  Timer? _vuelta;
  bool _preguntando = false;

  @override
  String build() {
    ref.onDispose(() => _vuelta?.cancel());
    listenSelf((_, url) => _vigilarVuelta(url));
    _vigilarVuelta(_inicial);
    return _inicial;
  }

  /// En el respaldo, pregunta por la principal hasta que conteste; fuera de
  /// él, no pregunta nada.
  void _vigilarVuelta(String url) {
    _vuelta?.cancel();
    _vuelta = null;
    if (respaldo.isEmpty || respaldo == principal || url != respaldo) return;
    _vuelta = Timer.periodic(vueltaCada, (_) async {
      if (_preguntando) return;
      _preguntando = true;
      try {
        final preguntar = _sonda ?? BackendResolver.responde;
        if (await preguntar(
              principal,
              BackendResolver.esperaPrincipalReintento,
            ) &&
            state == respaldo) {
          state = principal;
        }
      } finally {
        _preguntando = false;
      }
    });
  }

  /// Vuelve a elegir con `BackendResolver` y cambia solo si la respuesta es
  /// otra: con la misma URL, quien la mira no tiene por qué reconstruirse.
  Future<void> reResolver() async {
    final elegida = await BackendResolver.resolver(
      principal: principal,
      respaldo: respaldo,
      sonda: _sonda,
    );
    if (elegida != state) state = elegida;
  }
}

/// Si la app habla ahora con el respaldo y no con el principal.
///
/// Con D1 = espejo de la demo, el respaldo sirve una flota simulada a
/// propósito; el panel y el pasajero lo dicen en una línea para que nadie
/// confunda esa flota con la del túnel. Una URL fija, o un respaldo que es el
/// mismo principal, nunca lo está.
final enRespaldoProvider = Provider<bool>((ref) {
  final url = ref.watch(backendUrlProvider);
  final backend = ref.watch(backendUrlProvider.notifier);
  return backend.respaldo.isNotEmpty &&
      backend.respaldo != backend.principal &&
      url == backend.respaldo;
});

Future<List<T>> _getJsonList<T>(
  String backendUrl,
  String path,
  T Function(Map<String, dynamic>) fromJson,
) async {
  final response = await http
      .get(Uri.parse('$backendUrl$path'))
      .timeout(const Duration(seconds: 8));
  // Con su estado y su tipo, para que quien lo muestre sepa decir si fue
  // el servidor (`clasificarFallo`); un `Exception` con texto no se deja
  // distinguir sin leer la frase.
  if (response.statusCode != 200) throw RespuestaFallida(response.statusCode);
  final data = jsonDecode(response.body);
  if (data is! List) throw const FormatException('Respuesta inesperada');
  return data
      .map((item) => fromJson(Map<String, dynamic>.from(item as Map)))
      .toList();
}

final companiesProvider =
    FutureProvider.autoDispose<List<Company>>((ref) async {
  return _getJsonList(
      ref.watch(backendUrlProvider), '/api/companies', Company.fromJson);
});

// La empresa seleccionada es parte del estado persistente de la sesión (no
// es temporal de la hoja): con autoDispose, al cerrar el selector se
// desechaba y al reabrirlo decía "Primero selecciona una empresa" aunque la
// ruta siguiera activa. La limpieza explícita la hace resetAppState.
final selectedCompanyProvider =
    StateNotifierProvider<_SelectedCompanyNotifier, Company?>(
  (ref) => _SelectedCompanyNotifier(),
);

class _SelectedCompanyNotifier extends StateNotifier<Company?> {
  _SelectedCompanyNotifier() : super(null);

  void select(Company company) => state = company;
  void clear() => state = null;
}

final routesByCompanyProvider = FutureProvider.autoDispose
    .family<List<RouteInfo>, String>((ref, companyId) async {
  return _getJsonList(ref.watch(backendUrlProvider),
      '/api/companies/$companyId/routes', RouteInfo.fromJson);
});

// La ruta es estado de sesión igual que la empresa: no debe borrarse sola
// al cambiar de pantalla. Antes era autoDispose y se perdía si nadie la
// miraba; ahora persiste hasta que resetAppState la limpie.
final selectedRouteProvider =
    StateNotifierProvider<_SelectedRouteNotifier, RouteInfo?>(
  (ref) => _SelectedRouteNotifier(),
);

class _SelectedRouteNotifier extends StateNotifier<RouteInfo?> {
  _SelectedRouteNotifier() : super(null);

  void select(RouteInfo route) => state = route;
  void clear() => state = null;
}
