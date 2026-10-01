import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Por qué no llegó una respuesta del backend, en las clases que la app
/// distingue al decirlo.
///
/// Antes todo fallo era el mismo «Error al cargar empresas»: con el wifi
/// apagado la app culpaba al servidor, y con el túnel sin backend detrás le
/// tocaba al usuario adivinar si era su señal (dueño, 2026-09-30). Cada
/// clase pide algo distinto a quien la lee: revisar su red, esperar o nada.
enum FalloRed {
  /// El teléfono no llegó a hablar con nadie: sin datos, sin wifi o con un
  /// wifi sin salida a internet.
  sinConexion,

  /// Se pidió y nadie contestó a tiempo.
  lento,

  /// Contestó, pero mal: un 5xx, el túnel sin backend detrás o una página
  /// donde iba la lista.
  servidor,
}

/// El backend contestó con un estado que no es 200.
class RespuestaFallida implements Exception {
  const RespuestaFallida(this.estado);

  final int estado;

  @override
  String toString() => 'RespuestaFallida($estado)';
}

/// La clase de [error], tal como lo lanza una carga con `package:http`.
///
/// `package:http` envuelve el `SocketException` en un `ClientException`
/// (en iOS y Android son la misma excepción con las dos caras), así que los
/// dos son «sin conexión». Un wifi de portal cautivo responde al TLS con su
/// propio certificado y el apretón de manos falla: tampoco hay salida. Lo
/// que no se reconoce cuenta como del servidor, que es quien respondió.
FalloRed clasificarFallo(Object error) => switch (error) {
      TimeoutException() => FalloRed.lento,
      SocketException() || http.ClientException() || TlsException() =>
        FalloRed.sinConexion,
      _ => FalloRed.servidor,
    };
