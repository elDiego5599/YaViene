import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show Color;
import 'package:flutter/services.dart'
    show MethodChannel, MissingPluginException, PlatformException;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../utils/bus_labels.dart';
import '../utils/color_empresa.dart';
import 'cola_eventos.dart';
import 'ficha_ruta.dart';

/// El aviso que alguien tocó: el bus, su ruta y su empresa, para dejar el mapa
/// como estaba cuando sonó. Empresa es opcional para enlaces/notificaciones
/// antiguos; cuando viene evita confundir rutas con el mismo id.
@immutable
class AvisoTocado {
  const AvisoTocado({
    required this.busId,
    required this.routeId,
    this.companyId,
  });

  final String busId;
  final String routeId;
  final String? companyId;

  @override
  bool operator ==(Object other) =>
      other is AvisoTocado &&
      other.busId == busId &&
      other.routeId == routeId &&
      other.companyId == companyId;

  @override
  int get hashCode => Object.hash(busId, routeId, companyId);
}

/// Notificaciones locales de proximidad de buses (sin servidor).
///
/// Cada bus con alerta activa tiene su propio aviso (id estable por bus),
/// de una sola línea: «Tu bus de la ruta Calle 72 - Uninorte está cerca de
/// ti». Sin placa ni distancia (dueño, 2026-10-02): la placa y los metros
/// están en la hoja del mapa, que es lo que abre tocarlo.
class BusNotificationService {
  BusNotificationService._();

  static const _channelId = 'bus_alerts';
  static const _channelName = 'Alertas de buses';
  static const _actividad = MethodChannel('yaviene/actividad_en_vivo');

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    _actividad.setMethodCallHandler((llamada) async {
      if (llamada.method != 'avisoTocado') return;
      final carga = llamada.arguments;
      final aviso = leerUrlActividad(carga is String ? carga : null);
      if (aviso != null) {
        _tocados.agregar(aviso);
        try {
          await _actividad.invokeMethod<void>('confirmarAvisoPendiente');
        } on MissingPluginException {
          // Versiones anteriores del Runner no tenían confirmación; el
          // evento ya quedó retenido en Dart para el listener tardío.
        } on PlatformException catch (e) {
          debugPrint('no se pudo confirmar el toque de la actividad: $e');
        }
      }
    });
    // Si iOS recibió el widgetURL antes de que el handler o el mapa estuvieran
    // listos, el Runner conserva el enlace. Recuperarlo ahora evita depender
    // del orden engine → canal → suscripción de MapScreen.
    try {
      final enlace =
          await _actividad.invokeMethod<String>('leerAvisoPendiente');
      final aviso = leerUrlActividad(enlace);
      if (aviso != null) _tocados.agregar(aviso);
    } on MissingPluginException {
      // Android y versiones sin el canal de actividad no tienen este método.
    } on PlatformException catch (e) {
      debugPrint('no se pudo recuperar el toque de la actividad: $e');
    }
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      // En iOS, DarwinInitializationSettings pide los permisos al
      // inicializar salvo que se le diga que no, así que el cuadro de
      // "Ya Viene quiere enviarte notificaciones" salía nada más abrir la
      // app —encima del arranque, antes de que nadie hubiera visto para
      // qué sirven—. Justo lo que la guía de Apple dice no hacer, y lo
      // contrario de lo que promete `requestPermission` más abajo. Se
      // piden ahí, cuando el usuario activa su primer aviso.
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (respuesta) {
        final aviso = leerCarga(respuesta.payload);
        if (aviso != null) _tocados.agregar(aviso);
      },
    );
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: 'Avisos cuando un bus seleccionado se acerque a ti',
        importance: Importance.high,
      ),
    );
  }

  static final _tocados = ColaEventos<AvisoTocado>();

  /// Los avisos que se tocan con la app viva (en primer plano o en el
  /// fondo). El que la abrió desde cerrada llega por [tocadoAlAbrir].
  static Stream<AvisoTocado> get tocados => _tocados.stream;

  static bool _arranqueLeido = false;

  /// El aviso que abrió la app desde cerrada, una sola vez por proceso: si
  /// el mapa se vuelve a montar no repite la selección encima de lo que la
  /// persona haya escogido después.
  static Future<AvisoTocado?> tocadoAlAbrir() async {
    if (_arranqueLeido) return null;
    _arranqueLeido = true;
    try {
      final enlace =
          await _actividad.invokeMethod<String>('leerAvisoPendiente');
      final aviso = leerUrlActividad(enlace);
      if (aviso != null) return aviso;
    } on MissingPluginException {
      // El aviso normal de iOS no tiene una actividad asociada.
    } on PlatformException catch (e) {
      debugPrint('no se pudo leer el enlace de la actividad: $e');
    }
    try {
      final detalles = await _plugin.getNotificationAppLaunchDetails();
      if (detalles?.didNotificationLaunchApp != true) return null;
      return leerCarga(detalles!.notificationResponse?.payload);
    } catch (e) {
      debugPrint('no se pudo leer el aviso que abrió la app: $e');
      return null;
    }
  }

  /// Lo que viaja dentro del aviso, y su lectura. Cualquier cosa que no sea
  /// un bus y una ruta se ignora: tocar el aviso abre la app y ya.
  @visibleForTesting
  static String carga(String busId, String routeId, [String? companyId]) =>
      jsonEncode({
        'busId': busId,
        'routeId': routeId,
        if (companyId != null && companyId.isNotEmpty) 'companyId': companyId,
      });

  @visibleForTesting
  static AvisoTocado? leerCarga(String? carga) {
    if (carga == null || carga.isEmpty) return null;
    try {
      final datos = jsonDecode(carga);
      if (datos is! Map) return null;
      final busId = datos['busId'];
      final routeId = datos['routeId'];
      final companyId = datos['companyId'];
      if (busId is! String || busId.isEmpty) return null;
      if (routeId is! String || routeId.isEmpty) return null;
      if (companyId != null && companyId is! String) return null;
      if (companyId is String &&
          (companyId.trim().isEmpty || companyId.length > 256)) {
        return null;
      }
      return AvisoTocado(
        busId: busId,
        routeId: routeId,
        companyId: companyId as String?,
      );
    } on FormatException {
      return null;
    }
  }

  /// Lee el enlace de una actividad en vivo en la frontera de la app.
  @visibleForTesting
  static AvisoTocado? leerUrlActividad(String? valor) {
    if (valor == null || valor.length > 600) return null;
    final uri = Uri.tryParse(valor);
    if (uri == null || uri.scheme != 'yaviene' || uri.host != 'aviso') {
      return null;
    }
    final busId = uri.queryParameters['busId'];
    final routeId = uri.queryParameters['routeId'];
    final companyId = uri.queryParameters['companyId'];
    if (busId == null ||
        routeId == null ||
        busId.trim().isEmpty ||
        routeId.trim().isEmpty ||
        busId.length > 256 ||
        routeId.length > 256) {
      return null;
    }
    if (companyId != null &&
        (companyId.trim().isEmpty || companyId.length > 256)) {
      return null;
    }
    return AvisoTocado(busId: busId, routeId: routeId, companyId: companyId);
  }

  static Future<bool> areNotificationsEnabled() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      return await android.areNotificationsEnabled() ?? false;
    }
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) return (await ios.checkPermissions())?.isEnabled ?? false;
    return true;
  }

  /// Si un aviso se vería ahora: el permiso general dado y, en Android, el
  /// canal «Alertas de buses» sin apagar. Se puede apagar solo esa categoría
  /// en Ajustes con el permiso general intacto, y entonces Android descarta
  /// el aviso igual de callado.
  static Future<bool> puedeAvisar() async {
    if (!await areNotificationsEnabled()) return false;
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return true;
    try {
      final canales = await android.getNotificationChannels();
      for (final canal in canales ?? const <AndroidNotificationChannel>[]) {
        if (canal.id == _channelId) return canal.importance != Importance.none;
      }
    } catch (e) {
      // Sin la lista de canales no se sabe; el permiso general ya dijo que sí.
      debugPrint('no se pudo leer el canal de avisos: $e');
    }
    return true;
  }

  /// Pide el permiso de notificaciones (Android 13+) en el momento en que el
  /// usuario activa la alerta, no al abrir la app.
  static Future<bool> requestPermission() async {
    if (await areNotificationsEnabled()) return true;
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      return await ios.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }
    return false;
  }

  /// Notificación diferenciada por bus: id hash estable entre ejecuciones.
  ///
  /// Devuelve si el aviso llegó a mostrarse; si no, quien llama no lo da
  /// por enviado: el bus sigue en la lista de avisos activos y el barrido
  /// lo reintenta.
  ///
  /// Con el permiso revocado desde Ajustes, `show` no falla: ni Android ni
  /// iOS lanzan un error, el sistema descarta la notificación callado. Por
  /// eso se pregunta antes ([puedeAvisar]) en vez de fiarse de que `show`
  /// terminara bien (auditoría 2026-09, H2).
  static Future<bool> notifyBusNear({
    required String busId,
    String? routeName,
    String? routeId,
    String? companyId,
  }) async {
    final ruta = rutaLegible(routeName, routeId);
    try {
      if (!await puedeAvisar()) return false;
      final ficha =
          await _ficha(codigoRuta(routeName), colorFicha(companyId: companyId));
      final adjunto =
          ficha == null || defaultTargetPlatform != TargetPlatform.iOS
              ? null
              : await _adjuntar(ficha);
      await _plugin.show(
        id: _stableNotificationId(busId),
        // El texto es el del glosario (`aviso.app`); glosario_test lo ata.
        title: ruta == null
            ? 'Tu bus está cerca de ti'
            : 'Tu bus de la ruta $ruta está cerca de ti',
        payload: routeId == null || routeId.isEmpty
            ? null
            : carga(busId, routeId, companyId),
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            importance: Importance.high,
            priority: Priority.high,
            playSound: true,
            // El servidor vigila el aviso aunque la app esté viva (D13):
            // con la app en el fondo, el push y el barrido local pueden
            // llegar a la vez. Es la misma notificación (mismo id) y la
            // segunda no vuelve a sonar.
            onlyAlertOnce: true,
            largeIcon: ficha == null ? null : ByteArrayAndroidBitmap(ficha),
          ),
          iOS: DarwinNotificationDetails(
            attachments: [
              if (adjunto != null) DarwinNotificationAttachment(adjunto),
            ],
          ),
        ),
      );
      return true;
    } catch (e, st) {
      debugPrint('notifyBusNear failed for $busId: $e\n$st');
      // El aviso falla blando: nunca debe tumbar el flujo del mapa. Pero el
      // fallo se cuenta, para que el aviso siga armado y se reintente.
      return false;
    }
  }

  /// Quién pinta la ficha (inyectable en pruebas: una GPU apagada no se
  /// simula de otro modo).
  @visibleForTesting
  static Future<Uint8List> Function(String codigo, Color color) pintarFicha =
      fichaRuta;

  /// Las fichas ya pintadas, por código y color. Pocas: una por ruta con
  /// aviso en esta sesión.
  static final _fichas = <String, Uint8List>{};

  /// Lo que se espera a la GPU cuando la ficha no estaba pintada.
  static const _esperaFicha = Duration(seconds: 2);

  @visibleForTesting
  static void olvidarFichas() => _fichas.clear();

  /// Pinta la ficha del aviso al armarlo, con la app delante. Con el iPhone
  /// bloqueado iOS apaga la GPU de la app y `toImage` no termina nunca: el
  /// aviso que sonaba ahí se quedaba esperando y, con él, el barrido
  /// (dueño, 2026-10-29).
  static Future<void> prepararFicha({
    String? routeName,
    String? companyId,
  }) async {
    final codigo = codigoRuta(routeName);
    if (codigo == null) return;
    final color = colorFicha(companyId: companyId);
    final clave = _claveFicha(codigo, color);
    if (_fichas.containsKey(clave)) return;
    try {
      _fichas[clave] = await pintarFicha(codigo, color);
    } catch (e) {
      debugPrint('no se pudo pintar la ficha de $codigo: $e');
    }
  }

  static String _claveFicha(String codigo, Color color) =>
      '$codigo|${color.toARGB32()}';

  /// La ficha con el código de la ruta (B18, C16) que el aviso lleva de
  /// ícono (dueño, 2026-10-19). Si no hay código, no se pudo pintar o la GPU
  /// no contesta a tiempo, el aviso sale igual, sin ficha: nunca se pierde
  /// ni se atasca por un ícono.
  static Future<Uint8List?> _ficha(String? codigo, Color color) async {
    if (codigo == null) return null;
    final clave = _claveFicha(codigo, color);
    final guardada = _fichas[clave];
    if (guardada != null) return guardada;
    try {
      return _fichas[clave] =
          await pintarFicha(codigo, color).timeout(_esperaFicha);
    } catch (e) {
      debugPrint('no se pudo pintar la ficha de $codigo: $e');
      return null;
    }
  }

  /// iOS no deja cambiar el ícono de la app en el aviso: la ficha va como
  /// imagen adjunta, que el sistema enseña a la derecha. Pide un archivo y
  /// se lo lleva a su almacén al mostrarlo, así que se escribe uno nuevo
  /// cada vez.
  static Future<String?> _adjuntar(Uint8List ficha) async {
    try {
      final archivo = File(
        '${Directory.systemTemp.path}/ficha-'
        '${DateTime.now().microsecondsSinceEpoch}.png',
      );
      await archivo.writeAsBytes(ficha, flush: true);
      return archivo.path;
    } catch (e) {
      debugPrint('no se pudo guardar la ficha del aviso: $e');
      return null;
    }
  }

  /// Quita de la bandeja el aviso de [busId], si sigue ahí. Al armar otra
  /// vez ese bus el de antes ya no dice nada cierto, y con él en la bandeja
  /// el nuevo no sonaría (`onlyAlertOnce`). Falla blando, como
  /// [notifyBusNear].
  static Future<void> retirar(String busId) async {
    try {
      await _plugin.cancel(id: _stableNotificationId(busId));
    } catch (e) {
      debugPrint('no se pudo retirar el aviso de $busId: $e');
    }
  }
}

int _stableNotificationId(String value) {
  // String.hashCode no garantiza el mismo valor entre procesos; FNV-1a sí
  // permite reemplazar la notificación del mismo bus tras reabrir la app.
  var hash = 0x811c9dc5;
  for (final unit in value.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0x7fffffff;
  }
  return hash == 0 ? 1 : hash;
}
