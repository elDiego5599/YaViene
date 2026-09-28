import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Cuándo se supo del bus por última vez y a qué iba: «Último reporte ahora
/// · 32 km/h». Va en la ficha del bus seleccionado, que decía el estado
/// pero no la hora; «En línea» sin hora es una promesa y esto es un dato.
///
/// Si el bus se calla la cuenta sube sola («hace 4 s», «hace 5 s»…), y el
/// operador lo ve antes de que el servidor lo marque inactivo a los 90 s.
/// Mientras reporta cada segundo dice «ahora» y no parpadea entre «hace 0 s»
/// y «hace 1 s».
///
/// Cuenta en su propia capa: la ficha no se vuelve a pintar cada segundo.
class UltimoReporte extends StatefulWidget {
  const UltimoReporte({
    super.key,
    required this.reportadoEn,
    this.velocidadKmh,
    this.reloj = DateTime.now,
  });

  /// Cuándo recibió el servidor la última posición, en ms desde la época;
  /// `null` si el bus no ha reportado.
  final int? reportadoEn;

  /// La velocidad de ese reporte. Quien lo monta la pasa solo con el bus en
  /// línea: la de un bus callado es de hace rato y ya no dice nada.
  final double? velocidadKmh;

  /// De dónde sale la hora. Es un parámetro para que las pruebas la fijen.
  final DateTime Function() reloj;

  /// Hasta aquí es «ahora»: con un reporte por segundo, la edad va de 0 a 1 s
  /// y a veces un poco más por la red.
  static const umbralAhora = Duration(seconds: 2);

  /// «ahora», «hace 7 s», «hace 2 min», «hace 3 h», «hace 2 d».
  static String hace(Duration edad) {
    if (edad < umbralAhora) return 'ahora';
    if (edad.inMinutes < 1) return 'hace ${edad.inSeconds} s';
    if (edad.inHours < 1) return 'hace ${edad.inMinutes} min';
    if (edad.inDays < 1) return 'hace ${edad.inHours} h';
    return 'hace ${edad.inDays} d';
  }

  @override
  State<UltimoReporte> createState() => _UltimoReporteState();
}

class _UltimoReporteState extends State<UltimoReporte> {
  Timer? _latido;

  @override
  void initState() {
    super.initState();
    _armar();
  }

  @override
  void didUpdateWidget(covariant UltimoReporte viejo) {
    super.didUpdateWidget(viejo);
    if ((viejo.reportadoEn == null) != (widget.reportadoEn == null)) _armar();
  }

  /// Sin reporte no hay nada que contar y no hay latido.
  void _armar() {
    _latido?.cancel();
    _latido = widget.reportadoEn == null
        ? null
        : Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _latido?.cancel();
    super.dispose();
  }

  String get _texto {
    final reportadoEn = widget.reportadoEn;
    if (reportadoEn == null) return 'Sin reportes todavía';
    final edad = widget.reloj().difference(
      DateTime.fromMillisecondsSinceEpoch(reportadoEn),
    );
    // Un reloj del servidor adelantado daría una edad negativa: es «ahora».
    final hace = UltimoReporte.hace(edad.isNegative ? Duration.zero : edad);
    final velocidad = widget.velocidadKmh;
    return [
      'Último reporte $hace',
      if (velocidad != null) '${velocidad.round()} km/h',
    ].join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.schedule, size: 12, color: AppColors.textMuted),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              _texto,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppType.mono(
                fontSize: 10.5,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
