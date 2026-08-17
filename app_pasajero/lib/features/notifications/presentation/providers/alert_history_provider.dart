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

class AlertHistoryNotifier extends StateNotifier<List<AlertHistoryEntry>> {
  AlertHistoryNotifier() : super(const []);

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
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kHistoryKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final list = (jsonDecode(raw) as List)
          .map((e) => AlertHistoryEntry.fromJson(e as Map<String, dynamic>))
          .toList();
      state = list;
    } catch (_) {
      // Historial corrupto: se descarta; la próxima acción lo reescribe.
      state = const [];
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kHistoryKey,
      jsonEncode(state.map((e) => e.toJson()).toList()),
    );
  }
}

final alertHistoryProvider =
    StateNotifierProvider<AlertHistoryNotifier, List<AlertHistoryEntry>>(
        (ref) => AlertHistoryNotifier());