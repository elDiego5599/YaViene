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

  /// Momento en que se disparó la notificación. `null` = aviso aún activo.
  final DateTime? sentAt;

  const AlertHistoryEntry({
    required this.busId,
    required this.routeId,
    this.routeName,
    required this.createdAt,
    this.sentAt,
  });

  bool get sent => sentAt != null;

  AlertHistoryEntry copyWith({DateTime? sentAt}) => AlertHistoryEntry(
        busId: busId,
        routeId: routeId,
        routeName: routeName,
        createdAt: createdAt,
        sentAt: sentAt ?? this.sentAt,
      );

  Map<String, dynamic> toJson() => {
        'busId': busId,
        'routeId': routeId,
        'routeName': routeName,
        'createdAt': createdAt.toIso8601String(),
        'sentAt': sentAt?.toIso8601String(),
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
    );
  }
}

const _kHistoryKey = 'alert_history';
const _kLegacyMigratedUser = 'alert_history_legacy_migrated_user';

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
  String? _userId;

  String get _storageKey =>
      _userId == null ? _kHistoryKey : 'alert_history_user_$_userId';

  /// Armar un aviso crea (o renueva) su registro en estado activo.
  void upsert(String busId, {required String routeId, String? routeName}) {
    final entry = AlertHistoryEntry(
      busId: busId,
      routeId: routeId,
      routeName: routeName,
      createdAt: DateTime.now(),
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
  Future<void> load({String? userId}) async {
    if (_userId != userId) {
      await _saveQueue;
      _userId = userId;
      state = const [];
    }
    // No leer una versión antigua del disco mientras una activación reciente
    // todavía está terminando de persistirse.
    await _saveQueue;
    final prefs = await SharedPreferences.getInstance();
    var raw = prefs.getString(_storageKey);
    // Migración única de instalaciones anteriores a la versión con historial
    // por usuario. El dato legado se asigna al primer usuario que lo abre y
    // luego se elimina para que nunca se reutilice con otra cuenta.
    if (raw == null && userId != null) {
      final migratedUser = prefs.getString(_kLegacyMigratedUser);
      final legacy = prefs.getString(_kHistoryKey);
      if (migratedUser == null && legacy != null) {
        raw = legacy;
        await prefs.setString(_storageKey, legacy);
        await prefs.setString(_kLegacyMigratedUser, userId);
        await prefs.remove(_kHistoryKey);
      }
    }
    if (raw == null || raw.isEmpty) return;
    try {
      final list = (jsonDecode(raw) as List)
          .map((e) => AlertHistoryEntry.fromJson(e as Map<String, dynamic>))
          .toList();
      final purgado = _purgar(list);
      state = purgado;
      // Una instalación vieja puede traer el historial ya crecido: se
      // reescribe podado para que no vuelva a leerse entero mañana.
      if (purgado.length != list.length) _save();
    } catch (_) {
      // Historial corrupto: se descarta; la próxima acción lo reescribe.
      state = const [];
    }
  }

  void _save() {
    final purgado = _purgar(state);
    if (purgado.length != state.length) state = purgado;
    final encoded = jsonEncode(state.map((e) => e.toJson()).toList());
    final key = _storageKey;
    _saveQueue = _saveQueue.catchError((_) {}).then((_) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, encoded);
    });
  }
}

final alertHistoryProvider =
    StateNotifierProvider<AlertHistoryNotifier, List<AlertHistoryEntry>>(
        (ref) => AlertHistoryNotifier());
