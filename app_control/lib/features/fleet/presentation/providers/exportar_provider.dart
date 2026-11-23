import 'dart:io';

import 'package:clock/clock.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import 'fleet_providers.dart' show fleetApiProvider;
import 'reportes_provider.dart' show PeriodoReporte, rangoPeriodo;

/// Guarda [texto] donde la persona elija, con [nombre] de sugerencia.
/// Devuelve el nombre con que quedó, o null si cerró el diálogo.
typedef GuardarArchivo = Future<String?> Function(String nombre, String texto);

/// El diálogo de guardar de macOS y Windows. En macOS el sandbox solo deja
/// escribir lo que la persona eligió ahí (`files.user-selected.read-write`).
final guardarArchivoProvider = Provider<GuardarArchivo>(
  (ref) => (nombre, texto) async {
    final lugar = await getSaveLocation(
      suggestedName: nombre,
      acceptedTypeGroups: const [
        XTypeGroup(
          label: 'CSV',
          extensions: ['csv'],
          uniformTypeIdentifiers: ['public.comma-separated-values-text'],
        ),
      ],
    );
    if (lugar == null) return null;
    final archivo = File(lugar.path);
    await archivo.writeAsString(texto, flush: true);
    return archivo.uri.pathSegments.last;
  },
);

/// Los indicadores por hora de una ruta, en CSV, para el periodo de
/// Reportes. Primero se piden y luego se pregunta dónde guardar: así el
/// diálogo ya sugiere el nombre que da el servidor (ruta y fechas), y si
/// el servidor falla nadie elige un lugar para nada.
///
/// Devuelve el nombre del archivo guardado, o null si se canceló.
Future<String?> exportarIndicadoresCsv(
  Ref ref, {
  required String routeId,
  required PeriodoReporte periodo,
}) async {
  final token = ref.read(authProvider.select((s) => s.session?.token));
  final (desde, hasta) = rangoPeriodo(periodo, clock.now());
  final csv = await ref
      .read(fleetApiProvider)
      .fetchIndicadoresCsv(
        token,
        routeId: routeId,
        desde: desde,
        hasta: hasta,
        dias: periodo.dias,
      );
  return ref.read(guardarArchivoProvider)(csv.nombre, csv.texto);
}

/// Para llamar [exportarIndicadoresCsv] desde un botón con su `Ref`.
final exportarIndicadoresProvider =
    Provider<Future<String?> Function(String routeId, PeriodoReporte periodo)>(
      (ref) =>
          (routeId, periodo) =>
              exportarIndicadoresCsv(ref, routeId: routeId, periodo: periodo),
    );
