import 'package:flutter/material.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

/// La ocupación de [bus] en el tramo por donde va, a la hora de su
/// posición; null sin ruta o con el bus fuera de ella: sin tramo no hay qué
/// decir. Es de ejemplo (`ocupacionSimulada`) hasta que lleguen las cámaras.
/// La hora es la de la posición y no la del reloj: la cifra cambia cuando
/// el bus se mueve, no sola.
int? ocupacionEnRuta(SeguidorRuta? seguidor, BusPosition bus) {
  if (seguidor == null || seguidor.ruta.largo <= 0) return null;
  final avance = seguidor.avanceDe(bus);
  if (avance == null) return null;
  return ocupacionSimulada(
    busId: bus.busId,
    routeId: bus.routeId,
    tramo: avance / seguidor.ruta.largo,
    hora: bus.timestamp.toLocal(),
  );
}

/// «Ocupación aprox.» y su porcentaje, con una pista que se llena en la
/// escala de calor del panel (dueño, 2026-10-27). La cifra va en tinta: los
/// tonos de la escala no llegan a 4,5:1 sobre blanco, así que el color va
/// solo en la pista, que no se lee.
class OcupacionBus extends StatelessWidget {
  const OcupacionBus({super.key, required this.porcentaje});

  final int porcentaje;

  @override
  Widget build(BuildContext context) {
    final t = porcentaje.clamp(0, 100) / 100;
    return Semantics(
      label: 'Ocupación aproximada, $porcentaje por ciento',
      excludeSemantics: true,
      child: Container(
        // El filo de la tarjeta separa la cifra de la ocupación, como el de
        // debajo de la placa; 10 de aire, el mismo que bajo la placa.
        padding: const EdgeInsets.only(top: 10),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.hairline)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.people_alt_rounded,
                    size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Ocupación aprox.',
                    style: AppTextStyles.etiqueta
                        .copyWith(color: AppColors.textSecondary),
                  ),
                ),
                // Cifras tabulares: al pasar de 58 a 61 el número no baila.
                Text(
                  '$porcentaje %',
                  style: AppTextStyles.cuerpoFuerte.copyWith(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w500,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // 6 de alto y puntas redondas (la píldora da radio 3 aquí): una
            // píldora, no una barra de progreso.
            ClipRRect(
              key: const ValueKey('ocupacion-pista'),
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: SizedBox(
                height: 6,
                child: ColoredBox(
                  color: const Color(0xFFEEF0F3),
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
      ),
    );
  }
}
