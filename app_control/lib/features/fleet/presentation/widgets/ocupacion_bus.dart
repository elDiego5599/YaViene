import 'package:flutter/material.dart';
import 'package:ya_viene_core/ya_viene_core.dart'
    show AppMotion, BusPosition, SeguidorRuta, ocupacionEnRuta;

import '../../../../core/theme/app_theme.dart';
import '../../domain/fleet_bus.dart';
import 'escala_calor.dart';

/// La ocupación de ejemplo de [bus] en el tramo por donde va, la misma que
/// le enseña al pasajero la tarjeta del bus (`ocupacionEnRuta`, en el core).
/// Null sin ruta, sin posición o con el bus fuera de su recorrido.
int? ocupacionDeFlota(SeguidorRuta? seguidor, FleetBus bus) {
  final (routeId, lat, lon) = (bus.routeId, bus.lat, bus.lon);
  final hora = bus.capturedAt ?? bus.receivedAt;
  if (routeId == null || lat == null || lon == null || hora == null) {
    return null;
  }
  return ocupacionEnRuta(
    seguidor,
    BusPosition(
      busId: bus.busId,
      routeId: routeId,
      lat: lat,
      lon: lon,
      heading: bus.heading,
      speedKmh: bus.speedKmh,
      timestamp: DateTime.fromMillisecondsSinceEpoch(hora),
      isGhostBus: bus.isGhost,
    ),
  );
}

/// «OCUPACIÓN APROX.» y su porcentaje en la ficha del bus, bajo la
/// velocidad, con una pista que se llena en la escala de calor de Reportes
/// (dueño, 2026-10-27). El rótulo es el de VELOCIDAD; la cifra va en tinta
/// porque los tonos de la escala no llegan a 4,5:1 sobre la bandeja, así que
/// el color va solo en la pista, que no se lee.
class OcupacionBus extends StatelessWidget {
  const OcupacionBus({super.key, required this.porcentaje});

  final int porcentaje;

  @override
  Widget build(BuildContext context) {
    final t = porcentaje.clamp(0, 100) / 100;
    return Semantics(
      label: 'Ocupación aproximada: $porcentaje %',
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  'OCUPACIÓN APROX.',
                  style: AppType.mono(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
              // 12,5 como «km/h» y en negrita: un dato al lado de la cifra
              // grande de la velocidad, no otra cifra que compita con ella.
              Text(
                '$porcentaje %',
                style: AppType.mono(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // 6 de alto y puntas redondas, como la del pasajero: una píldora,
          // no una barra de progreso.
          ClipRRect(
            key: const ValueKey('ocupacion-pista'),
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: SizedBox(
              height: 6,
              child: ColoredBox(
                color: AppColors.border,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(end: t),
                  duration: AppMotion.duracion(context, AppMotion.pausado),
                  curve: AppMotion.curvaCambio,
                  builder: (context, valor, _) => FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: valor,
                    child: ColoredBox(
                      key: const ValueKey('ocupacion-relleno'),
                      color: colorEnEscala(valor),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
