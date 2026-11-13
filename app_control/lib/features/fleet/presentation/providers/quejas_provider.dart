import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ya_viene_core/ya_viene_core.dart' show MotivoQueja;

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/queja_panel.dart';
import 'fleet_providers.dart' show fleetApiProvider;
import 'reportes_provider.dart' show PeriodoReporte, rangoPeriodo;

/// Las quejas de Reportes con los filtros de la pantalla. Sin ruta, todas
/// las de la empresa; sin motivo, todos.
final quejasProvider =
    FutureProvider.family<
      ReporteQuejas,
      ({String? routeId, PeriodoReporte periodo, MotivoQueja? motivo})
    >((ref, args) async {
      // Ningún día elegido cae en el rango: vacío sin gastar una lectura.
      if (!args.periodo.cuentaAlgunDia) return ReporteQuejas.vacio;
      // Solo el token: otro cambio de la sesión no vuelve a pedir el reporte.
      final token = ref.watch(authProvider.select((s) => s.session?.token));
      final (desde, hasta) = rangoPeriodo(args.periodo, clock.now());
      return ref
          .watch(fleetApiProvider)
          .fetchQuejas(
            token,
            desde: desde,
            hasta: hasta,
            routeId: args.routeId,
            motivo: args.motivo,
            dias: args.periodo.dias,
          );
    });
