import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Una entrada del historial: `activo` (armado, esperando el aviso) o
/// `enviado` (la notificación ya se disparó). Activa hay a lo sumo una por
/// bus; enviadas, las que hayan sonado: volver a armar un bus que ya avisó
/// no borra el aviso de antes (dueño, 2026-10-02). El historial es además la
/// única fuente de persistencia de los avisos activos: al reabrir la app se
/// re-arman las entradas que no han enviado su notificación.
class AlertHistoryEntry {
  final String busId;
  final String routeId;
  final String? routeName;
  final DateTime createdAt;

  /// Punto de espera al que quedó fijado el aviso (pin manual). Se guarda con
  /// la entrada porque es lo único que sobrevive a cerrar la app: sin él, al
  /// re-armar el aviso se volvía a tomar la ubicación de ESE momento y el
  /// aviso se mudaba al pin nuevo. `null` = se mide en vivo (GPS).
  final double? refLat;
  final double? refLon;

  /// Momento en que se disparó la notificación. `null` = aviso aún activo.
  final DateTime? sentAt;

  /// Identificador del aviso en el servidor, que avisa por push con la app
  /// cerrada (Android, D13 del backend). `null` = el servidor no lo tiene.
  /// Se guarda porque el push llega a un proceso que no tiene nada en
  /// memoria: con él sabe si el push es de este aviso o de uno ya retirado.
  final String? servidorId;

  const AlertHistoryEntry({
    required this.busId,
    required this.routeId,
    this.routeName,
    required this.createdAt,
    this.sentAt,
    this.refLat,
    this.refLon,
    this.servidorId,
  });

  bool get sent => sentAt != null;

  /// Quién es esta entrada, entre varias del mismo bus.
  String get id => '$busId@${createdAt.microsecondsSinceEpoch}';

  AlertHistoryEntry copyWith({
    DateTime? sentAt,
    double? refLat,
    double? refLon,
  }) =>
      AlertHistoryEntry(
        busId: busId,
        routeId: routeId,
        routeName: routeName,
        createdAt: createdAt,
        sentAt: sentAt ?? this.sentAt,
        refLat: refLat ?? this.refLat,
        refLon: refLon ?? this.refLon,
        servidorId: servidorId,
      );

  /// La misma entrada con otro [servidorId] (también `null`, que `copyWith`
  /// no sabe poner).
  AlertHistoryEntry conServidor(String? id) => AlertHistoryEntry(
        busId: busId,
        routeId: routeId,
        routeName: routeName,
        createdAt: createdAt,
        sentAt: sentAt,
        refLat: refLat,
        refLon: refLon,
        servidorId: id,
      );

  Map<String, dynamic> toJson() => {
        'busId': busId,
        'routeId': routeId,
        'routeName': routeName,
        'createdAt': createdAt.toIso8601String(),
        'sentAt': sentAt?.toIso8601String(),
        'refLat': refLat,
        'refLon': refLon,
        if (servidorId != null) 'servidorId': servidorId,
      };

  factory AlertHistoryEntry.fromJson(Map<String, dynamic> json) {
    return AlertHistoryEntry(
      busId: json['busId'] as String,
      routeId: json['routeId'] as String? ?? '',
      routeName: json['routeName'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      sentAt: json['sentAt'] == null
          ? null
          : DateTime.parse(json['sentAt'] as String),
      // Entradas de versiones anteriores no traen ancla: quedan en vivo,
      // que es exactamente como se comportaban.
      refLat: (json['refLat'] as num?)?.toDouble(),
      refLon: (json['refLon'] as num?)?.toDouble(),
      servidorId: json['servidorId'] as String?,
    );
  }

  /// Lee una entrada del disco sin dejar que una sola mala tumbe el resto.
  /// `null` si no tiene forma de entrada: no es un mapa, no trae bus, una
  /// fecha no se entiende o un campo viene con otro tipo. El historial es
  /// también la única persistencia de los avisos activos, así que tirarlo
  /// entero por una entrada rota desarmaba en silencio todos los demás.
  static AlertHistoryEntry? tryFromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    try {
      final entry = AlertHistoryEntry.fromJson(json);
      return entry.busId.trim().isEmpty ? null : entry;
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }
}

const _kHistoryKey = 'alert_history';

/// Claves de cuando el historial se guardaba por cuenta
/// (`alert_history_user_<id>`) y la marca de a qué cuenta se le había dado
/// el historial anterior. Solo se leen para fundirlas en [_kHistoryKey] una
/// vez y borrarlas.
const _kPrefijoPorCuenta = 'alert_history_user_';
const _kLegacyMigratedUser = 'alert_history_legacy_migrated_user';

/// Lee una lista guardada sin fiarse de ella: lo que no sea una lista o una
/// entrada con forma se descarta.
List<AlertHistoryEntry> _leer(String? raw) {
  if (raw == null || raw.isEmpty) return const [];
  Object? decoded;
  try {
    decoded = jsonDecode(raw);
  } on FormatException {
    return const [];
  }
  if (decoded is! List) return const [];
  return decoded
      .map(AlertHistoryEntry.tryFromJson)
      .whereType<AlertHistoryEntry>()
      .toList();
}

/// Sin cuentas (D3), el historial es del teléfono. Quien usó la app con
/// cuenta tiene su historial en `alert_history_user_<id>` —uno por cada
/// cuenta que abrió en este teléfono— y ahí viven también sus avisos
/// activos, así que no se puede tirar: se funde todo en [_kHistoryKey], una
/// entrada por bus (la activada más tarde gana), y se borran las claves
/// viejas, que además guardaban el id de la cuenta. Devuelve lo fundido, o
/// `null` si no había nada que migrar.
Future<String?> _migrarPorCuenta(SharedPreferences prefs) async {
  final claves =
      prefs.getKeys().where((k) => k.startsWith(_kPrefijoPorCuenta)).toList();
  if (claves.isEmpty) {
    if (prefs.containsKey(_kLegacyMigratedUser)) {
      await prefs.remove(_kLegacyMigratedUser);
    }
    return null;
  }
  final porBus = <String, AlertHistoryEntry>{};
  for (final raw in [
    prefs.getString(_kHistoryKey),
    for (final clave in claves) prefs.getString(clave),
  ]) {
    for (final e in _leer(raw)) {
      final previa = porBus[e.busId];
      if (previa == null || e.createdAt.isAfter(previa.createdAt)) {
        porBus[e.busId] = e;
      }
    }
  }
  final fundido = jsonEncode(porBus.values.map((e) => e.toJson()).toList());
  await prefs.setString(_kHistoryKey, fundido);
  for (final clave in claves) {
    await prefs.remove(clave);
  }
  await prefs.remove(_kLegacyMigratedUser);
  return fundido;
}

/// El historial crecía sin techo: una entrada por cada bus al que se le haya
/// armado un aviso alguna vez, guardadas enteras en SharedPreferences y
/// releídas en cada arranque. Con una flota real eso son cientos de entradas
/// que nadie va a mirar. Se conservan las 50 más recientes de los últimos 30
/// días; los avisos todavía activos no se purgan mientras no venzan, porque
/// este archivo es además su única persistencia y borrarlos los desarmaría.
const int _maxEntradas = 50;
const Duration _vidaDelHistorial = Duration(days: 30);

/// Cuánto espera un aviso a que su bus llegue antes de darse por vencido.
///
/// Un bus que termina la jornada se va al patio, allí lo ocultan del mapa y
/// nadie sabe cuándo vuelve a salir. Sin fecha, su aviso se quedaba armado y
/// podía sonar a la mañana siguiente, cuando la persona ya no espera nada:
/// un aviso es para esta espera, no para la de mañana. Tres horas cubren con
/// margen una vuelta completa de cualquier ruta del piloto (hora y media a
/// dos horas y media en hora pico); si el bus no volvió en ese tiempo, es que
/// no está dando vueltas. El aviso vencido se borra como uno desactivado a
/// mano, que es lo que la persona habría hecho de haberse acordado.
const Duration vidaDeUnAviso = Duration(hours: 3);

/// El aviso sigue sin sonar y ya pasó su [vidaDeUnAviso].
bool avisoVencido(AlertHistoryEntry e, DateTime ahora) =>
    !e.sent && ahora.difference(e.createdAt) > vidaDeUnAviso;

List<AlertHistoryEntry> _purgar(List<AlertHistoryEntry> entradas) {
  final ahora = DateTime.now();
  final limite = ahora.subtract(_vidaDelHistorial);
  // Un activo vencido tampoco se guarda: al reabrir la app no se re-arma.
  final activas =
      entradas.where((e) => !e.sent && !avisoVencido(e, ahora)).toList();
  final enviadas = entradas
      .where((e) => e.sent && e.sentAt!.isAfter(limite))
      .toList()
    ..sort((a, b) => b.sentAt!.compareTo(a.sentAt!));

  final cupo = _maxEntradas - activas.length;
  final conservadas = cupo <= 0 ? <AlertHistoryEntry>[] : enviadas.take(cupo);
  // Se devuelve en el orden original para no reordenar la lista que ve el
  // usuario solo por haber purgado.
  final vivas = {...activas, ...conservadas};
  return entradas.where(vivas.contains).toList();
}

class AlertHistoryNotifier extends StateNotifier<List<AlertHistoryEntry>> {
  AlertHistoryNotifier() : super(const []);

  Future<void> _saveQueue = Future<void>.value();

  /// La entrada que espera de [busId], o -1.
  int _activa(String busId) =>
      state.indexWhere((e) => e.busId == busId && !e.sent);

  /// Armar un aviso crea (o renueva) el registro activo del bus.
  void upsert(
    String busId, {
    required String routeId,
    String? routeName,
    double? refLat,
    double? refLon,
  }) {
    final entry = AlertHistoryEntry(
      busId: busId,
      routeId: routeId,
      routeName: routeName,
      createdAt: DateTime.now(),
      refLat: refLat,
      refLon: refLon,
    );
    final index = _activa(busId);
    if (index == -1) {
      state = [...state, entry];
    } else {
      final next = [...state];
      next[index] = entry;
      state = next;
    }
    _save();
  }

  /// Fija el punto desde el que mide un aviso que medía en vivo. No es
  /// `upsert`: ese renueva la fecha, y la fecha decide cuándo vence.
  void fijarAncla(String busId, double lat, double lon) {
    final index = _activa(busId);
    if (index == -1) return;
    final next = [...state];
    next[index] = state[index].copyWith(refLat: lat, refLon: lon);
    state = next;
    _save();
  }

  /// Apunta (o borra, con `null`) el identificador del aviso activo de
  /// [busId] en el servidor.
  void fijarServidor(String busId, String? id) {
    final index = _activa(busId);
    if (index == -1 || state[index].servidorId == id) return;
    final next = [...state];
    next[index] = state[index].conServidor(id);
    state = next;
    _save();
  }

  /// El aviso disparó: el registro pasa a "enviado" con su fecha.
  void markSent(String busId) {
    final index = _activa(busId);
    if (index == -1) return;
    final next = [...state];
    next[index] = state[index].copyWith(sentAt: DateTime.now());
    state = next;
    _save();
  }

  /// Desactivación manual o vencimiento (nunca notificó): el registro
  /// activo del bus desaparece; lo que ya sonó se queda.
  void remove(String busId) {
    final index = _activa(busId);
    if (index == -1) return;
    state = [...state]..removeAt(index);
    _save();
  }

  /// Borra del historial las entradas [ids] (ver [AlertHistoryEntry.id]).
  void quitar(Set<String> ids) {
    final next = state.where((e) => !ids.contains(e.id)).toList();
    if (next.length == state.length) return;
    state = next;
    _save();
  }

  /// «Deshacer» de un borrado: devuelve las entradas de [antes] que ya no
  /// están, en su sitio y con sus fechas, y dice cuáles repuso. Lo que
  /// cambió entre tanto gana a la copia vieja: una que sonó sigue enviada,
  /// y un activo viejo no vuelve si su bus ya tiene otro armado.
  List<AlertHistoryEntry> reponer(List<AlertHistoryEntry> antes) {
    final ahora = {for (final e in state) e.id: e};
    final esperando = {
      for (final e in state)
        if (!e.sent) e.busId
    };
    final repuestas = <AlertHistoryEntry>[];
    final next = <AlertHistoryEntry>[];
    for (final e in antes) {
      final actual = ahora.remove(e.id);
      if (actual != null) {
        next.add(actual);
      } else if (e.sent || esperando.add(e.busId)) {
        next.add(e);
        repuestas.add(e);
      }
    }
    state = [...next, ...ahora.values];
    _save();
    return repuestas;
  }

  void clearAll() {
    if (state.isEmpty) return;
    state = const [];
    _save();
  }

  /// Carga el historial guardado (al arrancar la app o volver al mapa).
  Future<void> load() async {
    // No leer una versión antigua del disco mientras una activación reciente
    // todavía está terminando de persistirse.
    await _saveQueue;
    final prefs = await SharedPreferences.getInstance();
    // Un push con la app en el fondo lo atiende otro proceso de Dart, que
    // marca el aviso como enviado en el disco; la copia en memoria de este
    // no se entera sin releer.
    await prefs.reload();
    var raw = prefs.getString(_kHistoryKey);
    final fundido = await _migrarPorCuenta(prefs);
    if (fundido != null) raw = fundido;
    if (raw == null || raw.isEmpty) return;
    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      decoded = null;
    }
    if (decoded is! List) {
      // Ni siquiera es una lista: no hay entrada que rescatar. Se reescribe
      // vacío para no volver a tropezar con lo mismo en cada arranque.
      state = const [];
      _save();
      return;
    }
    // Entrada por entrada: antes una sola rota (una fecha a medias, un bus
    // que llegó como número) hacía saltar el `catch` y se perdía el
    // historial entero, avisos activos incluidos.
    final list = decoded
        .map(AlertHistoryEntry.tryFromJson)
        .whereType<AlertHistoryEntry>()
        .toList();
    final purgado = _purgar(list);
    state = purgado;
    // Se reescribe saneado si algo se cayó: por rota o por vieja (una
    // instalación antigua puede traer el historial ya crecido). Así lo que
    // se descartó no vuelve a leerse mañana.
    if (purgado.length != decoded.length) _save();
  }

  /// Se cumple cuando lo último que se cambió ya está en el disco.
  Future<void> get guardado => _saveQueue.catchError((_) {});

  void _save() {
    final purgado = _purgar(state);
    if (purgado.length != state.length) state = purgado;
    final encoded = jsonEncode(state.map((e) => e.toJson()).toList());
    _saveQueue = _saveQueue.catchError((_) {}).then((_) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kHistoryKey, encoded);
    });
  }
}

final alertHistoryProvider =
    StateNotifierProvider<AlertHistoryNotifier, List<AlertHistoryEntry>>(
        (ref) => AlertHistoryNotifier());
