import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Una entrada por bus en el historial: `activo` (armado, esperando el aviso)
/// o `enviado` (la notificación ya se disparó). El historial es además la
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

  const AlertHistoryEntry({
    required this.busId,
    required this.routeId,
    this.routeName,
    required this.createdAt,
    this.sentAt,
    this.refLat,
    this.refLon,
  });

  bool get sent => sentAt != null;

  AlertHistoryEntry copyWith({DateTime? sentAt}) => AlertHistoryEntry(
        busId: busId,
        routeId: routeId,
        routeName: routeName,
        createdAt: createdAt,
        sentAt: sentAt ?? this.sentAt,
        refLat: refLat,
        refLon: refLon,
      );

  Map<String, dynamic> toJson() => {
        'busId': busId,
        'routeId': routeId,
        'routeName': routeName,
        'createdAt': createdAt.toIso8601String(),
        'sentAt': sentAt?.toIso8601String(),
        'refLat': refLat,
        'refLon': refLon,
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
/// días; los avisos todavía activos nunca se purgan, porque este archivo es
/// además su única persistencia y borrarlos los desarmaría en silencio.
const int _maxEntradas = 50;
const Duration _vidaDelHistorial = Duration(days: 30);

List<AlertHistoryEntry> _purgar(List<AlertHistoryEntry> entradas) {
  final limite = DateTime.now().subtract(_vidaDelHistorial);
  final activas = entradas.where((e) => !e.sent).toList();
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

  /// Armar un aviso crea (o renueva) su registro en estado activo.
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
    final index = state.indexWhere((e) => e.busId == busId);
    if (index == -1) {
      state = [...state, entry];
    } else {
      final next = [...state];
      next[index] = entry;
      state = next;
    }
    _save();
  }

  /// El aviso disparó: el registro pasa a "enviado" con su fecha.
  void markSent(String busId) {
    final index = state.indexWhere((e) => e.busId == busId);
    if (index == -1) return;
    final next = [...state];
    next[index] = state[index].copyWith(sentAt: DateTime.now());
    state = next;
    _save();
  }

  /// Desactivación manual (nunca notificó): el registro desaparece.
  void remove(String busId) {
    final next = state.where((e) => e.busId != busId).toList();
    if (next.length == state.length) return;
    state = next;
    _save();
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
