import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/viaje_panel.dart';
import 'fleet_providers.dart' show fleetApiProvider;
import 'reportes_provider.dart' show PeriodoReporte, rangoPeriodo;

/// Los viajes buscados de Reportes. Sin franja, todo el día.
final viajesProvider =
    FutureProvider.family<
      ReporteViajes,
      ({PeriodoReporte periodo, int? franja})
    >((ref, args) async {
      // Ningún día elegido cae en el rango: vacío sin gastar una lectura.
      if (!args.periodo.cuentaAlgunDia) return ReporteViajes.vacio;
      final token = ref.watch(authProvider.select((s) => s.session?.token));
      final (desde, hasta) = rangoPeriodo(args.periodo, clock.now());
      return ref
          .watch(fleetApiProvider)
          .fetchViajes(
            token,
            desde: desde,
            hasta: hasta,
            franja: args.franja,
            dias: args.periodo.dias,
          );
    });
