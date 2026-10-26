import 'package:flutter/material.dart';
import 'package:ya_viene_core/ya_viene_core.dart' show AppMotion;

import '../../../../core/theme/app_theme.dart';

/// Ocupación por hora de un día de ejemplo, de 5 a. m. a 11 p. m. Ningún bus
/// tiene aún cámara de aforo (`YaVieneBackend/prototipo-aforo`), así que la
/// pestaña lo dice y enseña con datos de ejemplo lo que verá la empresa: los
/// picos de la mañana y la tarde llenos, el mediodía y la noche vacíos.
const _primeraHora = 5;
const _ejemplo = [
  38, 82, 88, 61, 42, 24, 18, 47, 44, 19, //
  26, 53, 84, 90, 63, 41, 30, 20, 12,
];

enum _Aforo {
  vacio('Vacío', AppColors.online),
  medio('Medio', AppColors.ghost),
  lleno('Lleno', AppColors.offline);

  const _Aforo(this.texto, this.color);
  final String texto;
  final Color color;

  // Hasta 20 % se va sentado; desde 80 %, de pie y apretado.
  static _Aforo de(int pct) => pct <= 20
      ? vacio
      : pct >= 80
      ? lleno
      : medio;
}

String _hora(int h) => '${h > 12 ? h - 12 : h}';
String _meridiano(int h) => h % 24 < 12 ? 'a. m.' : 'p. m.';

class OcupacionPanel extends StatefulWidget {
  const OcupacionPanel({super.key});

  @override
  State<OcupacionPanel> createState() => _OcupacionPanelState();
}

class _OcupacionPanelState extends State<OcupacionPanel> {
  // Arranca en la hora más llena, la que la empresa quiere ver primero.
  late int _elegida = _primeraHora + _ejemplo.indexOf(_ejemplo.reduce(_max));

  static int _max(int a, int b) => a > b ? a : b;

  @override
  Widget build(BuildContext context) {
    final pct = _ejemplo[_elegida - _primeraHora];
    final aforo = _Aforo.de(pct);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.sombraTarjeta,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Ocupación por hora',
                  style: AppType.ui(
                    color: AppColors.navy,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceRaised,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    'Datos de ejemplo',
                    style: AppType.ui(
                      color: AppColors.textSecondary,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // 64 px: la cifra es el dato de la pestaña, como en el video.
                Text(
                  '$pct %',
                  key: const ValueKey('aforo-cifra'),
                  style: AppType.ui(
                    color: aforo.color,
                    fontSize: 64,
                    fontWeight: FontWeight.w800,
                    height: 1,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: 14),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _Ficha(aforo: aforo),
                ),
                const SizedBox(width: 14),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    'de ${_hora(_elegida)} a ${_hora(_elegida + 1)} '
                    '${_meridiano(_elegida + 1)}',
                    style: AppType.ui(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < _ejemplo.length; i++)
                    Expanded(
                      child: _Barra(
                        hora: _primeraHora + i,
                        pct: _ejemplo[i],
                        elegida: _primeraHora + i == _elegida,
                        alTocar: () =>
                            setState(() => _elegida = _primeraHora + i),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              key: const ValueKey('ocupacion-sin-camaras'),
              children: [
                const Icon(
                  Icons.videocam_off_outlined,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Aún no hay buses con cámara de aforo conectada. Con ella, '
                    'un modelo de IA dirá cómo va cada bus.',
                    style: AppType.ui(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Estado del aforo en su color sobre su mismo tono al 8 %. Contraste medido
/// sobre ese fondo: verde 4,9:1, ámbar 4,85:1, rojo 4,83:1 (AA, 4,5:1).
class _Ficha extends StatelessWidget {
  const _Ficha({required this.aforo});

  final _Aforo aforo;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: AppMotion.normal,
    curve: AppMotion.curvaCambio,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
    decoration: BoxDecoration(
      color: Color.alphaBlend(
        aforo.color.withValues(alpha: 0.08),
        AppColors.surface,
      ),
      borderRadius: BorderRadius.circular(AppRadius.pill),
    ),
    child: Text(
      aforo.texto,
      key: const ValueKey('aforo-estado'),
      style: AppType.ui(
        color: aforo.color,
        fontSize: 15,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

/// Una hora: barra alta según su ocupación y su hora debajo. Vacío y lleno
/// van teñidos (rojo y verde al 30 %), lo medio en gris como en el video; la
/// hora elegida, en su color entero.
class _Barra extends StatelessWidget {
  const _Barra({
    required this.hora,
    required this.pct,
    required this.elegida,
    required this.alTocar,
  });

  final int hora;
  final int pct;
  final bool elegida;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    final aforo = _Aforo.de(pct);
    final tinte = elegida
        ? aforo.color
        : aforo == _Aforo.medio
        ? AppColors.borderStrong
        : Color.alphaBlend(
            aforo.color.withValues(alpha: 0.3),
            AppColors.surface,
          );
    final rotulo = AppType.ui(
      color: elegida ? AppColors.navy : AppColors.textSecondary,
      fontSize: 11,
      fontWeight: elegida ? FontWeight.w800 : FontWeight.w600,
      height: 1.2,
    );
    return Semantics(
      button: true,
      selected: elegida,
      label: '${_hora(hora)} ${_meridiano(hora)}, $pct %, ${aforo.texto}',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          key: ValueKey('aforo-hora-$hora'),
          behavior: HitTestBehavior.opaque,
          onTap: alTocar,
          child: Padding(
            // 6 px por lado: 12 de aire entre barras, como el ranking.
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Column(
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: FractionallySizedBox(
                      heightFactor: pct / 100,
                      child: AnimatedContainer(
                        duration: AppMotion.normal,
                        curve: AppMotion.curvaCambio,
                        decoration: BoxDecoration(
                          color: tinte,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                ExcludeSemantics(
                  child: Column(
                    children: [
                      Text(_hora(hora), style: rotulo),
                      Text(_meridiano(hora), style: rotulo),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
