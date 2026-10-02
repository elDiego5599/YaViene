import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:ya_viene_core/ya_viene_core.dart';

/// Lo que contesta el servidor a un latido de un aviso.
enum Latido {
  /// Sigue armado y el servidor no vigila durante un minuto más.
  renovado,

  /// El servidor ya avisó por push: la app no debe avisar otra vez.
  enviado,

  /// El servidor no lo tiene (venció, o se perdió): hay que volver a armarlo.
  noExiste,

  /// No hubo respuesta útil (sin red, el backend caído): se reintenta.
  fallo,
}

/// Los avisos con la app cerrada (D13 del backend), solo en Android.
///
/// La app avisa sola mientras está viva. Para cuando no lo está, le deja el
/// aviso al servidor: lo arma con `POST /api/avisos`, late cada 20 s con
/// `PUT` mientras sigue viva (el servidor no se mete mientras los latidos
/// llegan) y lo borra con `DELETE` al desarmarlo, al sonar o al vencer. Si
/// los latidos paran, el servidor mide por ella y manda un push de Firebase
/// Cloud Messaging, que la app convierte en la misma notificación de siempre.
///
/// iOS necesita la cuenta de Apple (APNs) y queda fuera por ahora: ahí
/// [token] es siempre `null` y nada de esto corre.
class AvisosPush {
  AvisosPush({
    required String Function() backend,
    http.Client? cliente,
    Future<String?> Function()? token,
  })  : _backend = backend,
        _cliente = cliente ?? http.Client(),
        _token = token ?? _tokenDeFirebase;

  final String Function() _backend;
  final http.Client _cliente;
  final Future<String?> Function() _token;

  static const _espera = Duration(seconds: 10);

  /// Firebase arrancó en este proceso ([iniciar]).
  static bool _listo = false;

  /// Arranca Firebase y deja registrado quién atiende un push con la app en
  /// el fondo o cerrada. Solo en Android; en cualquier otro sitio no hace
  /// nada. Falla blando: sin Firebase la app sigue avisando mientras esté
  /// abierta, que es lo que hacía siempre.
  static Future<void> iniciar(
    Future<void> Function(RemoteMessage) enElFondo,
  ) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(enElFondo);
      _listo = true;
    } catch (e) {
      debugPrint(
          'push: Firebase no arrancó, avisos solo con la app abierta: $e');
    }
  }

  static Future<String?> _tokenDeFirebase() async {
    if (!_listo) return null;
    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (e) {
      debugPrint('push: sin token de FCM: $e');
      return null;
    }
  }

  /// Los push que llegan con la app en primer plano (los de fondo van por el
  /// manejador de [iniciar]).
  static Stream<Map<String, dynamic>> get mensajes => _listo
      ? FirebaseMessaging.onMessage.map((m) => m.data)
      : const Stream.empty();

  /// El token de este teléfono, o `null` si aquí no hay push.
  Future<String?> token() => _token();

  /// El punto se manda redondeado a tres decimales, unos 100 m: alcanza para
  /// medir un radio de un kilómetro y no dice en qué casa espera nadie.
  static double _redondear(double grados) =>
      (grados * 1000).roundToDouble() / 1000;

  Uri _url(String ruta) => Uri.parse('${_backend()}$ruta');

  static const _json = {'Content-Type': 'application/json'};

  /// Arma el aviso en el servidor. Devuelve su identificador, o `apagado`
  /// si ese servidor no tiene push (sin la cuenta de servicio de Firebase):
  /// no tiene sentido volver a preguntar en cada latido.
  Future<({String? id, bool apagado})> armar({
    required String token,
    required String busId,
    required String routeId,
    required double lat,
    required double lon,
    required Duration vida,
  }) async {
    try {
      final r = await _cliente
          .post(
            _url('/api/avisos'),
            headers: _json,
            body: jsonEncode({
              'token': token,
              'busId': busId,
              'routeId': routeId,
              'lat': _redondear(lat),
              'lon': _redondear(lon),
              'vidaMs': vida.inMilliseconds,
            }),
          )
          .timeout(_espera);
      if (r.statusCode == 201) {
        final id = (jsonDecode(r.body) as Map<String, dynamic>)['id'];
        if (id is String && id.isNotEmpty) return (id: id, apagado: false);
      }
      return (id: null, apagado: _codigo(r) == 'PUSH_NO_DISPONIBLE');
    } catch (e) {
      final fallo = clasificarFallo(e).name;
      debugPrint('push: no se pudo armar el aviso de $busId: $fallo');
      return (id: null, apagado: false);
    }
  }

  /// Un latido: renueva el arriendo, el punto y el token.
  Future<Latido> latir(
    String id, {
    required String token,
    required double lat,
    required double lon,
  }) async {
    try {
      final r = await _cliente
          .put(
            _url('/api/avisos/${Uri.encodeComponent(id)}'),
            headers: _json,
            body: jsonEncode({
              'token': token,
              'lat': _redondear(lat),
              'lon': _redondear(lon),
            }),
          )
          .timeout(_espera);
      return switch (r.statusCode) {
        204 => Latido.renovado,
        410 => Latido.enviado,
        404 => Latido.noExiste,
        _ => Latido.fallo,
      };
    } catch (e) {
      debugPrint('push: latido sin respuesta: ${clasificarFallo(e).name}');
      return Latido.fallo;
    }
  }

  /// Borra el aviso del servidor. `false` si no se pudo (sin red): quien
  /// llama lo vuelve a intentar, porque un aviso huérfano ocupa uno de los
  /// dos cupos del teléfono hasta que vence.
  Future<bool> borrar(String id) async {
    try {
      final r = await _cliente
          .delete(_url('/api/avisos/${Uri.encodeComponent(id)}'))
          .timeout(_espera);
      return r.statusCode == 204 || r.statusCode == 404;
    } catch (e) {
      debugPrint(
          'push: no se pudo borrar el aviso: ${clasificarFallo(e).name}');
      return false;
    }
  }

  static String? _codigo(http.Response r) {
    try {
      final error = (jsonDecode(r.body) as Map<String, dynamic>)['error'];
      return error is Map ? error['code'] as String? : null;
    } catch (_) {
      return null;
    }
  }
}

final avisosPushProvider = Provider<AvisosPush>(
  (ref) => AvisosPush(backend: () => ref.read(backendUrlProvider)),
);
