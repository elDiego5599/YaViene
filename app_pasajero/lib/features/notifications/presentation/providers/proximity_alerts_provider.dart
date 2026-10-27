import 'dart:async';
import 'dart:ui' show DartPluginRegistrant;

import 'package:firebase_messaging/firebase_messaging.dart' show RemoteMessage;
import 'package:flutter/foundation.dart' show debugPrint, visibleForTesting;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import '../../../../core/services/actividad_en_vivo.dart';
import '../../../../core/services/bus_notification_service.dart';
import '../../../../core/services/mantener_vivo.dart';
import '../../../../core/utils/bus_labels.dart';
import '../../../../core/utils/distancia.dart';
import '../../../map/presentation/providers/tracking_providers.dart';
import '../../../map/presentation/providers/user_location_provider.dart';
import '../../../map/presentation/utils/geo.dart';
import '../../data/avisos_push.dart';
import 'alert_history_provider.dart';
import 'distancia_aviso_provider.dart';

/// Cuánto tiene que alejarse un bus ya avisado, más allá de la distancia de
/// su aviso, para poder volver a sonar (histéresis). Va sobre la distancia
/// de cada aviso y no es una cifra fija: con avisos de hasta 3 km, un rearme
/// fijo de 1500 m quedaba por dentro del radio y el bus sonaba otra vez en el
/// barrido siguiente sin haberse movido. 500 m le sobran al salto del GPS
/// del bus en el borde. La hoja suelta su bloqueo con el mismo margen.
const int margenRearmeMetros = 500;

/// Firma del disparo de notificación (inyectable en tests). Devuelve si el
/// aviso llegó a mostrarse: un aviso que no se mostró no se da por enviado.
typedef BusNearNotifier = Future<bool> Function({
  required String busId,
  String? routeName,
  String? routeId,
  String? companyId,
  required int distanceMeters,
});

/// Si el teléfono puede enseñar un aviso ahora (inyectable en tests).
typedef PermisoDeAvisos = Future<bool> Function();

/// Quita de la bandeja el aviso de un bus (inyectable en tests).
typedef RetirarAviso = Future<void> Function(String busId);

/// Cada cuánto late en el servidor un aviso armado: el latido mueve el
/// punto y el token, y responde 410 si el servidor ya avisó. El servidor
/// vigila el aviso desde que se arma, sin esperar a que los latidos falten
/// (D13 del backend).
const cadaLatidoPush = Duration(seconds: 20);

/// Cuánto se deja de intentar el push cuando el servidor dice que no lo
/// tiene (sin la cuenta de servicio de Firebase): preguntar en cada latido
/// sería ruido; diez minutos dejan que vuelva solo cuando lo configuren.
const pausaSinPush = Duration(minutes: 10);

/// Hay avisos armados que no pueden sonar porque las notificaciones de la
/// app están apagadas. Lo pone el barrido cuando un aviso no se pudo
/// mostrar y lo lee la hoja del mapa para decirlo (auditoría 2026-09, H2).
final avisosSinPermisoProvider = StateProvider<bool>((ref) => false);

/// Vigila el bus con aviso activo (selección única) y dispara una notificación
/// local cuando entra a la distancia de su aviso (la que eligió la persona)
/// de la ubicación del usuario (GPS o pin). Solo avisa una vez por
/// acercamiento.
class ProximityAlertsNotifier extends StateNotifier<Set<String>> {
  ProximityAlertsNotifier(
    this._ref, {
    BusNearNotifier? notify,
    PermisoDeAvisos? permiso,
    DateTime Function()? ahora,
    AvisosPush? push,
    RetirarAviso? retirar,
    ActividadEnVivo enVivo = const ActividadEnVivoCanal(),
    ServicioMantenerVivo? mantenerVivo,
    Future<void> Function()? sentir,
  })  : _enVivo = enVivo,
        _mantenerVivo = mantenerVivo ?? MantenerVivoIos(),
        _sentir = sentir ?? _dobleToque,
        _notify = notify ?? _defaultNotify,
        _permiso = permiso ?? BusNotificationService.puedeAvisar,
        _retirar = retirar ?? BusNotificationService.retirar,
        _ahora = ahora ?? DateTime.now,
        _push = push,
        super({}) {
    _ref.listen<UserLocationState>(userLocationProvider, _alMoverUbicacion);
  }

  final Ref _ref;
  final BusNearNotifier _notify;
  final PermisoDeAvisos _permiso;
  final RetirarAviso _retirar;

  /// La pantalla bloqueada y la Dynamic Island del bus que se sigue.
  final ActividadEnVivo _enVivo;

  /// Stream de ubicación de fondo mientras hay avisos armados en iOS.
  final ServicioMantenerVivo _mantenerVivo;

  /// Lo que se siente en la mano cuando suena un aviso ([_dobleToque]).
  final Future<void> Function() _sentir;

  /// Dos toques fuertes, como una alarma que suena: uno solo se confunde
  /// con cualquier botón. Con la app cerrada no hace nada; ahí vibra la
  /// notificación.
  static Future<void> _dobleToque() async {
    // Sin la plataforma (pruebas de lógica, aislado de fondo) no hay mano que
    // sentir: el aviso suena igual.
    try {
      await HapticFeedback.heavyImpact();
      await Future<void>.delayed(const Duration(milliseconds: 140));
      await HapticFeedback.heavyImpact();
    } catch (_) {}
  }

  /// Clave y hora del último envío de la actividad del bus seguido. Los estados
  /// iguales se reenvían cada 30 s para renovar su vigencia en iOS.
  final _enVivoMostrado = <String, (String, DateTime)>{};

  /// ActivityKit crea/actualiza la actividad de forma asíncrona. Serializar
  /// mostrar y terminar conserva su orden sin detener el barrido si el canal
  /// tarda o no responde. Si la cola está libre, despacha en esta misma
  /// llamada.
  final _colaEnVivo = <Future<void> Function()>[];
  bool _despachandoEnVivo = false;

  /// Reloj con el que se decide si un aviso venció (inyectable en tests:
  /// esperar tres horas de verdad no es una prueba).
  final DateTime Function() _ahora;
  Timer? _timer;

  /// Los avisos con la app cerrada (D13 del backend). `null` = sin push
  /// (las pruebas que no lo miran); en iOS existe pero no tiene token y no
  /// hace nada.
  final AvisosPush? _push;
  Timer? _timerPush;
  StreamSubscription<Map<String, dynamic>>? _mensajes;

  /// Identificador en el servidor de cada aviso armado que el servidor ya
  /// tiene.
  final _servidor = <String, String>{};

  /// Avisos del servidor que hay que borrar y todavía no se pudo (sin red al
  /// desarmar). Se reintentan en cada vuelta: un huérfano ocupa el cupo del
  /// teléfono y podría sonar por un aviso ya retirado.
  final _porBorrar = <String>{};

  /// Hasta cuándo no se arma nada en el servidor ([pausaSinPush]).
  DateTime? _pushPausadoHasta;
  Future<void>? _sincronizando;
  bool _otraVuelta = false;

  /// Ruta a la que pertenece cada bus con aviso armado. Necesaria para que el
  /// aviso siga midiendo aunque el usuario esté viendo otra ruta.
  final _alertRoutes = <String, String>{};

  /// Referencia geográfica de cada aviso armado con pin manual (snapshot de
  /// la ubicación al armarse). `null` = se mide en vivo contra la ubicación
  /// actual (GPS activo, o todavía sin ubicación al armar).
  final _alertRefs = <String, (double, double)?>{};

  /// Distancia a la que suena cada aviso armado (m): la que eligió la
  /// persona al armarlo o después, con «Cambiar».
  final _alertRadios = <String, int>{};

  /// Suscripciones de posiciones por ruta armada: solo se mantienen mientras
  /// haya avisos activos en esa ruta.
  final _routeSubs =
      <String, ProviderSubscription<AsyncValue<List<BusPosition>>>>{};
  final _routePositions = <String, List<BusPosition>>{};

  /// El seguidor del recorrido de cada ruta armada, con la misma vida que
  /// [_routeSubs]: mide por la calle y no en línea recta.
  final _seguidorSubs = <String, ProviderSubscription<SeguidorRuta?>>{};
  bool _monitoringPaused = false;

  static Future<bool> _defaultNotify({
    required String busId,
    String? routeName,
    String? routeId,
    String? companyId,
    // La distancia ya no se dice en el aviso (dueño, 2026-10-02); llega
    // igual porque las pruebas miden con ella cuándo sonó.
    required int distanceMeters,
  }) =>
      BusNotificationService.notifyBusNear(
        busId: busId,
        routeName: routeName,
        routeId: routeId,
        companyId: companyId,
      );

  /// BusIds que ya notificaron su acercamiento (armados): no vuelven a
  /// notificar hasta que se alejen [margenRearmeMetros] más allá de su
  /// distancia.

  void start() {
    if (_timer != null) return;
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _check());
    if (_push != null) {
      _timerPush = Timer.periodic(cadaLatidoPush, (_) => sincronizarPush());
      _mensajes = AvisosPush.mensajes.listen(alPush);
    }
  }

  /// Detiene el timer periódico. Idempotente; [start] lo relanza.
  void stop() {
    _timer?.cancel();
    _timer = null;
    _timerPush?.cancel();
    _timerPush = null;
    _mensajes?.cancel();
    _mensajes = null;
  }

  /// Fuerza una verificación (útil en tests).
  Future<void> check() => _check();

  /// Re-arma los avisos activos persistidos (al reabrir la app o al volver
  /// al mapa). Idempotente: un aviso ya armado en memoria no se duplica. Las
  /// entradas "enviadas" no se re-arman.
  Future<void> restore() async {
    _monitoringPaused = true;
    try {
      await _ref.read(alertHistoryProvider.notifier).load();
      final entries = _ref.read(alertHistoryProvider);
      for (final e in entries) {
        if (!e.sent && !rearmar(e)) {
          // El cupo o los datos impiden rearmarlo: no dejes una alerta
          // pendiente sin vigía ni su copia antigua en el servidor.
          final id = e.servidorId;
          if (id != null) _porBorrar.add(id);
          _ref.read(alertHistoryProvider.notifier).remove(e.busId);
        }
      }
    } finally {
      _monitoringPaused = false;
    }
    if (_push != null && _porBorrar.isNotEmpty) {
      unawaited(sincronizarPush());
    }
    // Al abrir la app con avisos armados se mira si pueden sonar: el
    // permiso se pudo quitar en Ajustes mientras la app estaba cerrada.
    if (_ref.read(activeAlertsProvider).isNotEmpty) {
      _anotarPermiso(await _preguntarPermiso());
    }
  }

  /// Vuelve a armar un aviso que está en el historial, con su ancla de
  /// entonces. Lo usan [restore] y el «Deshacer» de la pantalla de avisos.
  /// `false` si ya se sigue otro bus.
  bool rearmar(AlertHistoryEntry e) {
    if (e.routeId.isEmpty) return false;
    final wasMonitoring =
        _alertRoutes[e.busId] == e.routeId && _routeSubs.containsKey(e.routeId);
    if (!_ref.read(activeAlertsProvider.notifier).activateAlert(e.busId)) {
      return false;
    }
    final enServidor = e.servidorId;
    if (enServidor != null) _servidor.putIfAbsent(e.busId, () => enServidor);
    if (!wasMonitoring) {
      // Ancla guardada, no la ubicación de ahora: re-armar leyendo la
      // posición actual mudaba el aviso al pin nuevo (o lo dejaba en
      // vivo si el GPS todavía no había respondido).
      _armMonitoring(
        e.busId,
        e.routeId,
        recordHistory: false,
        ancla: e.refLat != null && e.refLon != null
            ? (e.refLat!, e.refLon!)
            : null,
        radioM: e.radioM,
      );
    }
    return true;
  }

  /// Pregunta al sistema; `null` si no contesta (sin plugin, o un error del
  /// canal): no saber no cambia lo que la hoja ya dice.
  Future<bool?> _preguntarPermiso() async {
    try {
      return await _permiso();
    } catch (e) {
      debugPrint('no se pudo leer el permiso de notificaciones: $e');
      return null;
    }
  }

  void _anotarPermiso(bool? concedido) {
    if (!mounted || concedido == null) return;
    _ref.read(avisosSinPermisoProvider.notifier).state = !concedido;
  }

  /// Registra la ruta del bus al armar el aviso y suscribe posiciones de esa
  /// ruta: el aviso mide aunque la pantalla esté mostrando otra ruta. Suena
  /// cuando el bus está a [radioM] o menos.
  void armAlert(
    String busId,
    String routeId, {
    int radioM = distanciaAvisoInicial,
  }) {
    _armMonitoring(
      busId,
      routeId,
      recordHistory: true,
      ancla: _anclaActual(),
      radioM: radioM,
    );
  }

  /// Distancia a la que suena el aviso armado de [busId]; `null` si no hay.
  int? radioDe(String busId) => _alertRadios[busId];

  /// «Cambiar» con un aviso armado: el aviso sigue (misma ancla, misma
  /// fecha) y mide con [radioM]. En el servidor es otro aviso: el de antes
  /// se borra y el siguiente latido arma este, porque allá el radio se fija
  /// al armar.
  void cambiarRadio(String busId, int radioM) {
    final antes = _alertRadios[busId];
    if (antes == null || antes == radioM) return;
    _alertRadios[busId] = radioM;
    state = {...state}..remove(busId);
    final historial = _ref.read(alertHistoryProvider.notifier)
      ..fijarRadio(busId, radioM);
    final viejo = _servidor.remove(busId);
    if (viejo != null) {
      _porBorrar.add(viejo);
      historial.fijarServidor(busId, null);
    }
    unawaited(sincronizarPush());
  }

  /// Punto de espera al que se fija un aviso nuevo: el pin manual de ahora.
  /// Con GPS activo queda `null` → el aviso mide en vivo, porque ahí el punto
  /// de espera es el usuario, que se mueve con él.
  (double, double)? _anclaActual() {
    final location = _ref.read(userLocationProvider);
    return location.mode == UserLocationMode.manual && location.hasPosition
        ? (location.lat!, location.lon!)
        : null;
  }

  /// Un aviso armado con GPS no tiene ancla: mide desde la persona, que se
  /// mueve con él. Pero al poner o arrastrar el pin, «en vivo» pasaba a ser
  /// el pin y el aviso se mudaba con él (lo vio el dueño, 2026-09-28). Al
  /// pasar de GPS a pin, esos avisos se quedan donde estaba el GPS. Igual
  /// al quitar el pin del GPS («Quitar»): el próximo punto lo toca el
  /// usuario y el aviso no se muda a él. Solo en esos pasos: GPS →
  /// «ubicando» es el mismo GPS volviendo a leer.
  void _alMoverUbicacion(UserLocationState? antes, UserLocationState ahora) {
    if (antes == null ||
        antes.mode != UserLocationMode.gps ||
        !antes.hasPosition ||
        (ahora.mode != UserLocationMode.manual &&
            ahora.mode != UserLocationMode.sinPunto)) {
      return;
    }
    final donde = (antes.lat!, antes.lon!);
    final historial = _ref.read(alertHistoryProvider.notifier);
    for (final busId in _alertRoutes.keys) {
      if (_alertRefs[busId] != null) continue;
      _alertRefs[busId] = donde;
      historial.fijarAncla(busId, donde.$1, donde.$2);
    }
  }

  /// Ancla de un aviso armado, para que la pantalla mida la distancia desde
  /// el mismo punto desde el que mide el aviso.
  (double, double)? anchorFor(String busId) => _alertRefs[busId];

  void _armMonitoring(
    String busId,
    String routeId, {
    required bool recordHistory,
    required (double, double)? ancla,
    required int radioM,
  }) {
    _monitoringPaused = false;
    final primerAviso = _alertRoutes.isEmpty;
    _alertRoutes[busId] = routeId;
    if (primerAviso) unawaited(_mantenerVivo.iniciar());
    _alertRadios[busId] = radioM;
    // Re-armado limpio: si este bus ya notificó su acercamiento antes (quedó
    // marcado en `state`), se borra esa marca para que pueda volver a sonar
    // en un nuevo acercamiento; si no, el aviso re-armado quedaba "muerto".
    state = {...state}..remove(busId);
    // Registro en el historial: la activación queda anotada (y es la fuente
    // de persistencia para re-armar al volver a abrir la app).
    if (recordHistory) {
      // Un aviso nuevo es otro aviso también en el servidor: el de antes
      // (si quedaba) se borra y el siguiente latido arma este.
      final viejo = _servidor.remove(busId);
      if (viejo != null) _porBorrar.add(viejo);
      // La notificación de un acercamiento anterior de este bus sale de la
      // bandeja: si se quedara, la nueva no sonaría (`onlyAlertOnce`).
      unawaited(_retirar(busId));
      _ref.read(alertHistoryProvider.notifier).upsert(
            busId,
            routeId: routeId,
            routeName: _ref.read(selectedRouteProvider)?.name,
            companyId: switch (_ref.read(selectedRouteProvider)?.companyId) {
              final String id when id.isNotEmpty => id,
              _ => null,
            },
            refLat: ancla?.$1,
            refLon: ancla?.$2,
            radioM: radioM,
          );
    }
    // Ancla del aviso: el punto de espera con el que se armó. Aunque luego se
    // quite el pin (sin GPS la app queda sin ubicación) o se ponga otro pin
    // para armar otro bus, este aviso sigue midiendo desde donde se armó.
    _alertRefs[busId] = ancla;
    _routeSubs.putIfAbsent(routeId, () {
      return _ref.listen<AsyncValue<List<BusPosition>>>(
        busPositionsSourceProvider(routeId),
        (previous, next) {
          _routePositions[routeId] = next.value ?? const [];
        },
        fireImmediately: true,
      );
    });
    _seguidorSubs.putIfAbsent(
      routeId,
      () => _ref.listen(seguidorRutaProvider(routeId), (_, __) {}),
    );
    unawaited(sincronizarPush());
  }

  /// Olvida la ruta del bus; si era el último aviso de esa ruta, se cierra la
  /// suscripción (se desuscribe del socket).
  void disarmAlert(String busId) {
    _terminarEnVivo(busId, llego: false);
    final enServidor = _servidor.remove(busId);
    if (enServidor != null) {
      _porBorrar.add(enServidor);
      unawaited(sincronizarPush());
    }
    _alertRefs.remove(busId);
    _alertRadios.remove(busId);
    final routeId = _alertRoutes.remove(busId);
    if (routeId == null) return;
    if (!_alertRoutes.containsValue(routeId)) {
      _routeSubs.remove(routeId)?.close();
      _seguidorSubs.remove(routeId)?.close();
      _routePositions.remove(routeId);
    }
    if (_alertRoutes.isEmpty) unawaited(_mantenerVivo.detener());
  }

  /// Limpia el registro de avisos disparados/rearmados. Lo que el servidor
  /// tiene no se borra: los avisos siguen en el historial y el mapa los
  /// re-arma enseguida, con el mismo identificador.
  void clear() {
    _monitoringPaused = false;
    unawaited(_mantenerVivo.detener());
    for (final busId in [..._enVivoMostrado.keys]) {
      _terminarEnVivo(busId, llego: false);
    }
    state = {};
    _servidor.clear();
    _alertRoutes.clear();
    _alertRefs.clear();
    _alertRadios.clear();
    for (final sub in [..._routeSubs.values, ..._seguidorSubs.values]) {
      sub.close();
    }
    _routeSubs.clear();
    _seguidorSubs.clear();
    _routePositions.clear();
  }

  @override
  void dispose() {
    unawaited(_mantenerVivo.detener());
    _timer?.cancel();
    _timerPush?.cancel();
    _mensajes?.cancel();
    for (final sub in [..._routeSubs.values, ..._seguidorSubs.values]) {
      sub.close();
    }
    _routeSubs.clear();
    _seguidorSubs.clear();
    _alertRefs.clear();
    super.dispose();
  }

  void _mostrarEnVivo(String busId, double metros, int radio) {
    final entrada = _entradaActiva(busId);
    final estado = EstadoEnVivo(
      busId: busId,
      routeId: _alertRoutes[busId] ?? '',
      companyId: entrada?.companyId,
      placa: busPlaca(busId),
      ruta: nombreSinCodigo(entrada?.routeName),
      // La cifra de la hoja, con su decimal pasados 10 km.
      distancia: _cifraDeLaHoja(metros),
      aviso: 'Te avisamos a ${distanciaAviso(radio)}',
      avance: EstadoEnVivo.avanceDe(metros),
      avanceAviso: EstadoEnVivo.avanceDe(radio.toDouble()),
    );
    final clave = '${estado.companyId}|${estado.routeId}|${estado.distancia}|'
        '${estado.aviso}|${estado.ruta}|'
        '${estado.avance.toStringAsFixed(2)}';
    final ahora = _ahora();
    final ultimo = _enVivoMostrado[busId];
    if (ultimo != null &&
        ultimo.$1 == clave &&
        ahora.difference(ultimo.$2) < const Duration(seconds: 30)) {
      return;
    }
    _enVivoMostrado[busId] = (clave, ahora);
    _encolarEnVivo(() => _enVivo.mostrar(estado));
  }

  void _terminarEnVivo(String busId, {required bool llego}) {
    if (_enVivoMostrado.remove(busId) == null) return;
    _encolarEnVivo(() => _enVivo.terminar(busId, llego: llego));
  }

  void _encolarEnVivo(Future<void> Function() accion) {
    _colaEnVivo.add(accion);
    _despacharEnVivo();
  }

  void _despacharEnVivo() {
    if (_despachandoEnVivo || _colaEnVivo.isEmpty) return;
    _despachandoEnVivo = true;
    final accion = _colaEnVivo.removeAt(0);
    Future<void>.sync(accion).then(
      (_) {
        _despachandoEnVivo = false;
        _despacharEnVivo();
      },
      onError: (Object error, StackTrace stack) {
        debugPrint('actividad en vivo falló: $error');
        _despachandoEnVivo = false;
        _despacharEnVivo();
      },
    );
  }

  /// La entrada que espera de [busId] en el historial.
  AlertHistoryEntry? _entradaActiva(String busId) {
    for (final e in _ref.read(alertHistoryProvider)) {
      if (e.busId == busId && !e.sent) return e;
    }
    return null;
  }

  /// El aviso de [busId] ya sonó por otro lado (el push): queda enviado,
  /// fuera de los activos y marcado como avisado, igual que si hubiera
  /// sonado aquí.
  void _yaSono(String busId) {
    _terminarEnVivo(busId, llego: true);
    _ref.read(alertHistoryProvider.notifier).markSent(busId);
    _ref.read(activeAlertsProvider.notifier).deactivateAlert(busId);
    disarmAlert(busId);
    state = {...state, busId};
  }

  /// Pone al día el servidor con los avisos armados: borra lo pendiente,
  /// arma lo que falta y late por lo que ya tiene. Corre cada
  /// [cadaLatidoPush] y al armar o desarmar; si llega otra mientras corre,
  /// la que corre da una vuelta más y las dos terminan juntas.
  Future<void> sincronizarPush() {
    final push = _push;
    if (push == null || !mounted) return Future.value();
    final enCurso = _sincronizando;
    if (enCurso != null) {
      _otraVuelta = true;
      return enCurso;
    }
    return _sincronizando =
        _sincronizar(push).whenComplete(() => _sincronizando = null);
  }

  Future<void> _sincronizar(AvisosPush push) async {
    do {
      _otraVuelta = false;
      await _sincronizarUnaVez(push);
    } while (_otraVuelta && mounted);
  }

  Future<void> _sincronizarUnaVez(AvisosPush push) async {
    for (final id in [..._porBorrar]) {
      if (await push.borrar(id)) _porBorrar.remove(id);
      if (!mounted) return;
    }
    if (_alertRoutes.isEmpty) return;
    final pausa = _pushPausadoHasta;
    if (pausa != null && _ahora().isBefore(pausa)) return;
    final token = await push.token();
    if (token == null || !mounted) return;
    final location = _ref.read(userLocationProvider);
    final liveRef =
        location.hasPosition ? (location.lat!, location.lon!) : null;
    for (final MapEntry(key: busId, value: routeId) in [
      ..._alertRoutes.entries
    ]) {
      if (_alertRoutes[busId] != routeId) continue;
      // El mismo punto desde el que mide la app.
      final punto = _alertRefs[busId] ?? liveRef;
      if (punto == null) continue;
      final id = _servidor[busId];
      if (id == null) {
        final entrada = _entradaActiva(busId);
        if (entrada == null) continue;
        // Lo que le queda, no tres horas más: el servidor no debe avisar
        // después de que el aviso venció aquí. Nunca más de tres horas, aunque
        // el reloj haya ido hacia atrás desde que se armó.
        final vida = vidaDeUnAviso - _ahora().difference(entrada.createdAt);
        if (vida <= Duration.zero) continue;
        final vidaTope = vida > vidaDeUnAviso ? vidaDeUnAviso : vida;
        final radio = _alertRadios[busId] ?? entrada.radioM;
        final r = await push.armar(
          token: token,
          busId: busId,
          routeId: routeId,
          lat: punto.$1,
          lon: punto.$2,
          vida: vidaTope,
          radioM: radio,
        );
        if (!mounted) return;
        if (r.apagado) {
          _pushPausadoHasta = _ahora().add(pausaSinPush);
          return;
        }
        final nuevo = r.id;
        if (nuevo == null) continue;
        // Se desarmó, se volvió a armar o cambió de distancia mientras el
        // servidor contestaba: lo que se armó ya no es de nadie.
        if (_alertRoutes[busId] != routeId ||
            _alertRadios[busId] != radio ||
            _servidor.containsKey(busId) ||
            _entradaActiva(busId)?.createdAt != entrada.createdAt) {
          _porBorrar.add(nuevo);
          _otraVuelta = true;
          continue;
        }
        _servidor[busId] = nuevo;
        _ref.read(alertHistoryProvider.notifier).fijarServidor(busId, nuevo);
      } else {
        final latido = await push.latir(
          id,
          token: token,
          lat: punto.$1,
          lon: punto.$2,
        );
        if (!mounted) return;
        if (_servidor[busId] != id) continue;
        switch (latido) {
          case Latido.enviado:
            // El servidor avisó mientras la app no latía. Si el push llegó,
            // el proceso de fondo lo marcó en el disco: se relee antes de
            // escribir nada, o esta copia vieja taparía la suya.
            await _conciliar();
            if (!mounted) return;
            if (_servidor[busId] == id) _rearmarEnServidor(busId);
          case Latido.noExiste:
            _rearmarEnServidor(busId);
          case Latido.renovado:
          case Latido.fallo:
            break;
        }
      }
    }
  }

  /// El servidor ya no tiene el aviso (venció allá, se perdió, o avisó sin
  /// que nadie lo viera): se olvida su identificador y se arma otra vez.
  void _rearmarEnServidor(String busId) {
    _servidor.remove(busId);
    _ref.read(alertHistoryProvider.notifier).fijarServidor(busId, null);
    _otraVuelta = true;
  }

  /// Relee el historial del disco y da por sonados los avisos armados que
  /// el proceso de fondo marcó como enviados al atender un push.
  Future<void> _conciliar() async {
    await _ref.read(alertHistoryProvider.notifier).load();
    if (!mounted) return;
    for (final busId in [..._alertRoutes.keys]) {
      if (_entradaActiva(busId) == null) _yaSono(busId);
    }
  }

  /// Un push que llega con la app en primer plano: la app lo enseña como
  /// sus propios avisos, si es del aviso que sigue armado.
  Future<void> alPush(Map<String, dynamic> data) async {
    final busId = data['busId'];
    final avisoId = data['avisoId'];
    final distancia = int.tryParse('${data['distancia']}');
    if (data['tipo'] != 'bus_cerca' ||
        busId is! String ||
        avisoId is! String ||
        distancia == null ||
        _servidor[busId] != avisoId) {
      return;
    }
    final mostrado = await _notify(
      busId: busId,
      routeName: _entradaActiva(busId)?.routeName,
      routeId: _alertRoutes[busId],
      companyId: _entradaActiva(busId)?.companyId,
      distanceMeters: distancia,
    );
    if (!mounted || _servidor[busId] != avisoId) return;
    if (mostrado) {
      _anotarPermiso(true);
      unawaited(_sentir());
      _yaSono(busId);
    } else {
      // No se vio: el aviso sigue armado aquí y en el servidor, que lo
      // gastó, se arma otra vez.
      _rearmarEnServidor(busId);
      unawaited(sincronizarPush());
    }
  }

  /// La app vuelve al frente: lo que sonó por push mientras estaba en el
  /// fondo se da por sonado y el servidor se pone al día.
  Future<void> alVolver() async {
    if (_push == null || !mounted) return;
    await _conciliar();
    await sincronizarPush();
  }

  /// Retira los avisos que pasaron su [vidaDeUnAviso] sin sonar: el caso
  /// típico es un bus que se fue al patio, donde lo ocultan, y no volvió.
  /// Se van igual que uno desactivado a mano: fuera de los activos, sin
  /// suscripción y fuera del historial.
  void _vencer(Set<String> alerts) {
    final ahora = _ahora();
    for (final e in _ref.read(alertHistoryProvider)) {
      if (!alerts.contains(e.busId) || !avisoVencido(e, ahora)) continue;
      _ref.read(activeAlertsProvider.notifier).deactivateAlert(e.busId);
      disarmAlert(e.busId);
      _ref.read(alertHistoryProvider.notifier).remove(e.busId);
      if (state.contains(e.busId)) state = {...state}..remove(e.busId);
    }
  }

  /// Hay un barrido en curso. `Timer.periodic` dispara cada 5 s sin esperar
  /// a que el anterior termine, y el barrido espera a que cada notificación
  /// se muestre: el primer aviso en iOS se queda esperando a que la persona
  /// conteste el permiso, y ese rato puede durar varios ticks. El tick
  /// siguiente veía el mismo bus dentro del radio, todavía sin marcar, y lo
  /// avisaba otra vez. Mientras uno corre, los que llegan se saltan; el
  /// siguiente tick libre vuelve a medir con datos frescos.
  bool _checkInFlight = false;

  Future<void> _check() async {
    if (_checkInFlight) return;
    _checkInFlight = true;
    try {
      await _checkOnce();
    } finally {
      _checkInFlight = false;
    }
  }

  Future<void> _checkOnce() async {
    if (_monitoringPaused) return;
    final alerts = _ref.read(activeAlertsProvider);
    if (alerts.isEmpty) {
      if (state.isNotEmpty) state = {};
      return;
    }
    _vencer(alerts);
    final location = _ref.read(userLocationProvider);
    // Referencia por defecto: la ubicación actual (GPS o pin). Un aviso armado
    // con pin manual usa SU snapshot (_alertRefs) aunque la ubicación actual
    // haya desaparecido (pin quitado) o haya cambiado (pin nuevo): por eso ya
    // no se sale temprano cuando no hay posición en vivo.
    final liveRef =
        location.hasPosition ? (location.lat!, location.lon!) : null;

    final rearm = <String>{};
    final fire = <String, int>{};
    for (final busId in _ref.read(activeAlertsProvider)) {
      // Preferir la ruta registrada o la del historial. El último fallback
      // conserva compatibilidad con un aviso efímero armado por un consumidor
      // antiguo que solo marcó activeAlerts; durante logout está bloqueado por
      // `_monitoringPaused`, así que no puede medir otra ruta por accidente.
      var routeId = _alertRoutes[busId];
      if (routeId == null) {
        for (final entry in _ref.read(alertHistoryProvider)) {
          if (entry.busId == busId && !entry.sent && entry.routeId.isNotEmpty) {
            routeId = entry.routeId;
            break;
          }
        }
      }
      routeId ??= _ref.read(selectedRouteProvider)?.id;
      if (routeId == null) continue;
      final positions = _routePositions[routeId] ??
          _ref.read(busPositionsSourceProvider(routeId)).value ??
          const <BusPosition>[];
      // Sin posición (o sin señal): no hay nada que medir todavía.
      BusPosition? pos;
      for (final p in positions) {
        if (p.busId == busId) {
          pos = p;
          break;
        }
      }
      if (pos == null || pos.isGhostBus) continue;
      final ref = _alertRefs[busId] ?? liveRef;
      if (ref == null) continue;
      // Por la ruta: un bus que ya pasó el punto cuenta hasta su vuelta
      // siguiente y, si ya sonó, puede volver a sonar entonces.
      final distance =
          distanciaAlBus(_seguidorSubs[routeId]?.read(), pos, ref.$1, ref.$2);
      final radio = _alertRadios[busId] ??
          _entradaActiva(busId)?.radioM ??
          distanciaAvisoInicial;
      if (state.contains(busId)) {
        if (distance > radio + margenRearmeMetros) rearm.add(busId);
      } else {
        // Publica primero la distancia, incluso si la ruta ya llegó al radio:
        // al restaurar tras un cierre en frío ActivityKit puede no conservar
        // ninguna actividad, y el envío la desarma en esta misma vuelta.
        _mostrarEnVivo(busId, distance, radio);
        if (distance <= radio) fire[busId] = distance.round();
      }
    }

    if (fire.isNotEmpty) {
      // Sólo los que de verdad se mostraron. El resto se queda como está
      // —armado, activo y sin marcar— y el barrido de dentro de cinco
      // segundos lo vuelve a intentar mientras el bus siga dentro del radio.
      final enviados = <String>{};
      var fallidos = 0;
      for (final entry in fire.entries) {
        // Nombre de ruta y placa del bus para el texto de la notificación.
        String? routeName;
        String? companyId;
        for (final e in _ref.read(alertHistoryProvider)) {
          // El que espera: un enviado del mismo bus puede ser de otra ruta.
          if (e.busId == entry.key && !e.sent) {
            routeName = e.routeName;
            companyId = e.companyId;
            break;
          }
        }
        final mostrado = await _notify(
          busId: entry.key,
          routeName: routeName,
          routeId: _alertRoutes[entry.key],
          companyId: companyId,
          distanceMeters: entry.value,
        );
        if (!mounted) return;
        if (!mostrado) {
          fallidos++;
          continue;
        }
        enviados.add(entry.key);
        unawaited(_sentir());
        _terminarEnVivo(entry.key, llego: true);
        // El aviso ya se envió: pasa a "enviado" en el historial, sale de la
        // lista de alertas activas (visible en la pantalla de
        // Notificaciones) y se libera la suscripción de su ruta.
        _ref.read(alertHistoryProvider.notifier).markSent(entry.key);
        _ref.read(activeAlertsProvider.notifier).deactivateAlert(entry.key);
        disarmAlert(entry.key);
      }
      // Uno que sonó prueba que hay permiso. Si ninguno sonó se pregunta,
      // para que la hoja diga por qué el aviso no llega.
      if (enviados.isNotEmpty) {
        _anotarPermiso(true);
      } else if (fallidos > 0) {
        _anotarPermiso(await _preguntarPermiso());
      }
      if (!mounted) return;
      if (enviados.isNotEmpty) {
        state = {...state, ...enviados}..removeAll(rearm);
      } else if (rearm.isNotEmpty) {
        state = {...state}..removeAll(rearm);
      }
    } else if (rearm.isNotEmpty) {
      state = {...state}..removeAll(rearm);
    }
  }
}

final proximityAlertsProvider =
    StateNotifierProvider<ProximityAlertsNotifier, Set<String>>((ref) {
  return ProximityAlertsNotifier(ref, push: ref.read(avisosPushProvider));
});

/// Atiende un push con la app en el fondo o cerrada. Corre en un proceso de
/// Dart aparte, sin nada en memoria: lo que sabe del aviso lo lee del
/// historial en el disco. Lo registra [AvisosPush.iniciar].
@pragma('vm:entry-point')
Future<void> alRecibirPushEnFondo(RemoteMessage mensaje) async {
  DartPluginRegistrant.ensureInitialized();
  await atenderPushEnFondo(mensaje.data);
}

/// El cuerpo de [alRecibirPushEnFondo], con el aviso inyectable.
@visibleForTesting
Future<void> atenderPushEnFondo(
  Map<String, dynamic> data, {
  BusNearNotifier? notify,
}) async {
  final busId = data['busId'];
  final avisoId = data['avisoId'];
  final distancia = int.tryParse('${data['distancia']}');
  if (data['tipo'] != 'bus_cerca' ||
      busId is! String ||
      avisoId is! String ||
      distancia == null) {
    return;
  }
  final contenedor = ProviderContainer();
  final historial = contenedor.read(alertHistoryProvider.notifier);
  try {
    await historial.load();
    AlertHistoryEntry? entrada;
    for (final e in contenedor.read(alertHistoryProvider)) {
      if (e.busId == busId && !e.sent && e.servidorId == avisoId) entrada = e;
    }
    // Retirado o ya sonado: el push llegó tarde y no se enseña.
    if (entrada == null) return;
    if (notify == null) await BusNotificationService.init();
    final mostrado = await (notify ?? ProximityAlertsNotifier._defaultNotify)(
      busId: busId,
      routeName: entrada.routeName,
      routeId: entrada.routeId,
      companyId: entrada.companyId,
      distanceMeters: distancia,
    );
    if (!mostrado) return;
    historial.markSent(busId);
    await historial.guardado;
  } catch (e) {
    debugPrint('push: no se pudo atender el aviso de $busId: $e');
  } finally {
    contenedor.dispose();
  }
}

/// La distancia como la dice la hoja («10,6 km», «850 m»): la actividad en
/// vivo la espeja, y [distanciaAviso] quita el decimal desde 10 km.
String _cifraDeLaHoja(double metros) {
  final (cifra, unidad) = distanciaPartes(metros, '');
  return '$cifra ${unidad.trim()}';
}
