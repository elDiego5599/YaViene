import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

import '../../../core/utils/bus_labels.dart';
import '../../../core/utils/color_empresa.dart';
import '../../../core/widgets/ficha_ruta.dart';
import '../../../core/widgets/placa_bus.dart';
import '../../../core/widgets/sheet_handle.dart';
import '../../../core/widgets/titulo_seccion.dart';
import '../../map/presentation/providers/tracking_providers.dart';
import '../../map/presentation/widgets/rueda_distancia.dart'
    show franjaRuedaDistancia;
import '../data/buzon.dart';

/// Hasta cuántos días atrás se puede contar una queja: hoy y los seis de
/// antes. El backend no recibe nada de hace más de 7 días
/// (`MAX_ANTIGUEDAD_MS` en `src/data/quejas.ts`).
const _diasAtras = 7;

const _dias = ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];

/// «3 p. m.»: la hora como se dice en Barranquilla, sin minutos porque la
/// queja se guarda con la hora en punto.
String _horaLegible(int hora) {
  final doce = hora % 12 == 0 ? 12 : hora % 12;
  return '$doce ${hora < 12 ? 'a. m.' : 'p. m.'}';
}

/// «Hoy», «Ayer» o «lun 9» para el día de hace [atras] días.
String _diaLegible(int atras, DateTime hoy) {
  if (atras == 0) return 'Hoy';
  if (atras == 1) return 'Ayer';
  final dia = DateTime(hoy.year, hoy.month, hoy.day - atras);
  return '${_dias[dia.weekday - 1]} ${dia.day}';
}

/// «Ayer, 3 p. m.»: cuándo pasó, como lo dice la fila de la queja.
String cuandoLegible(DateTime hora, DateTime ahora) {
  final atras = DateTime(ahora.year, ahora.month, ahora.day)
      .difference(DateTime(hora.year, hora.month, hora.day));
  // Redondeado: un día con cambio de hora no mide 24 h justas.
  final dias = (atras.inHours / 24).round();
  return '${_diaLegible(dias, ahora)}, ${_horaLegible(hora.hour)}';
}

/// Lo que la queja pregunta además del mensaje (D18): el motivo, que es lo
/// único obligatorio, y los detalles que el pasajero quiera dar. La ruta, el
/// bus y la hora se eligen en su hoja; la zona, con un interruptor que nace
/// apagado: sin ese sí, del teléfono no sale ningún lugar.
class CamposQueja extends StatelessWidget {
  const CamposQueja({
    super.key,
    required this.motivo,
    required this.ruta,
    required this.bus,
    required this.hora,
    required this.compartir,
    required this.hayPunto,
    required this.alElegirMotivo,
    required this.alElegirRuta,
    required this.alElegirBus,
    required this.alElegirHora,
    required this.alCompartir,
  });

  final MotivoQueja? motivo;
  final RouteInfo? ruta;

  /// El id del bus; nulo si no se sabe cuál fue.
  final String? bus;

  /// Nula mientras no se elija: la queja sale con la hora de ahora.
  final DateTime? hora;
  final bool compartir;

  /// Si hay un punto en el mapa (GPS o pin) del que compartir la zona.
  final bool hayPunto;

  final ValueChanged<MotivoQueja> alElegirMotivo;
  final ValueChanged<RouteInfo> alElegirRuta;
  final ValueChanged<String?> alElegirBus;
  final ValueChanged<DateTime> alElegirHora;
  final ValueChanged<bool> alCompartir;

  Future<void> _elegirRuta(BuildContext context) async {
    final elegida = await _abrirHoja<RouteInfo>(
      context,
      titulo: '¿En qué ruta?',
      cuerpo: _HojaRutas(elegida: ruta?.id),
    );
    if (elegida != null) alElegirRuta(elegida);
  }

  Future<void> _elegirBus(BuildContext context, RouteInfo ruta) async {
    final elegido = await _abrirHoja<String>(
      context,
      titulo: '¿Cuál bus?',
      cuerpo: _HojaBuses(rutaId: ruta.id, elegido: bus),
    );
    // Vacío es «No sé cuál»; nulo, que cerró la hoja sin elegir.
    if (elegido != null) alElegirBus(elegido.isEmpty ? null : elegido);
  }

  Future<void> _elegirHora(BuildContext context) async {
    final elegida = await _abrirHoja<DateTime>(
      context,
      titulo: '¿Cuándo pasó?',
      cuerpo: _HojaHora(inicial: hora),
    );
    if (elegida != null) alElegirHora(elegida);
  }

  @override
  Widget build(BuildContext context) {
    final ruta = this.ruta;
    final bus = this.bus;
    final hora = this.hora;
    final codigo = codigoRuta(ruta?.name);
    final nombreRuta = nombreSinCodigo(ruta?.name) ?? ruta?.name;
    final cuando = hora == null ? 'Ahora' : cuandoLegible(hora, DateTime.now());
    final secundario =
        AppTextStyles.cuerpo.copyWith(color: AppColors.textSecondary);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const TituloSeccion('Motivo'),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final opcion in MotivoQueja.values)
              _Motivo(
                key: ValueKey('queja_motivo_${opcion.clave}'),
                texto: opcion.texto,
                elegido: opcion == motivo,
                alPulsar: () => alElegirMotivo(opcion),
              ),
          ],
        ),
        const TituloSeccion('Detalles'),
        DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: AppColors.filo),
          ),
          child: Column(
            children: [
              _Fila(
                key: const ValueKey('queja_ruta'),
                rotulo: 'Ruta',
                leido: nombreRuta ?? 'Elige la ruta',
                alPulsar: () => _elegirRuta(context),
                valor: ruta == null
                    ? Text(
                        'Elige la ruta',
                        style: AppTextStyles.cuerpo.copyWith(
                          color: AppColors.acento,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (codigo != null) ...[
                            FichaRuta(
                              codigo,
                              color: colorFicha(companyId: ruta.companyId),
                              lado: 28,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                          ],
                          Flexible(
                            child: Text(
                              nombreRuta!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.cuerpo
                                  .copyWith(color: AppColors.textPrimary),
                            ),
                          ),
                        ],
                      ),
              ),
              const _Raya(),
              // El bus se busca dentro de su ruta: sin ruta no hay de dónde.
              _Fila(
                key: const ValueKey('queja_bus'),
                rotulo: 'Bus',
                leido: bus != null
                    ? 'placa ${busPlaca(bus)}'
                    : ruta == null
                        ? 'Elige primero la ruta'
                        : 'Opcional',
                alPulsar: ruta == null ? null : () => _elegirBus(context, ruta),
                valor: bus != null
                    ? PlacaBus(busPlaca(bus))
                    : Text(
                        ruta == null ? 'Elige primero la ruta' : 'Opcional',
                        style: secundario,
                      ),
              ),
              const _Raya(),
              _Fila(
                key: const ValueKey('queja_hora'),
                rotulo: 'Cuándo',
                leido: cuando,
                alPulsar: () => _elegirHora(context),
                valor: Text(
                  cuando,
                  style: hora == null
                      ? secundario
                      : AppTextStyles.cuerpo
                          .copyWith(color: AppColors.textPrimary),
                ),
              ),
              const _Raya(),
              MergeSemantics(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.md, 12, 12, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Compartir la zona de tu punto',
                              style: AppTextStyles.cuerpo
                                  .copyWith(color: AppColors.textPrimary),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              hayPunto
                                  ? 'Solo la zona (unos 150 m), no tu punto '
                                      'exacto.'
                                  : 'Pon tu punto en el mapa para compartirla.',
                              style: AppTextStyles.pie
                                  .copyWith(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Switch.adaptive(
                        key: const ValueKey('queja_lugar'),
                        value: compartir && hayPunto,
                        activeTrackColor: AppColors.primary,
                        onChanged: hayPunto ? alCompartir : null,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// La raya entre dos filas de la tarjeta, a ras del texto.
class _Raya extends StatelessWidget {
  const _Raya();

  @override
  Widget build(BuildContext context) => const Divider(
        height: 1,
        thickness: 1,
        indent: AppSpacing.md,
        color: AppColors.filo,
      );
}

/// Un motivo: píldora de 44 de alto, blanca con filo y, elegida, llena en
/// el azul de botón con letra blanca (7,1:1).
class _Motivo extends StatelessWidget {
  const _Motivo({
    super.key,
    required this.texto,
    required this.elegido,
    required this.alPulsar,
  });

  final String texto;
  final bool elegido;
  final VoidCallback alPulsar;

  @override
  Widget build(BuildContext context) {
    final radio = BorderRadius.circular(AppRadius.pill);
    return Semantics(
      button: true,
      selected: elegido,
      label: texto,
      onTap: alPulsar,
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: AppMotion.duracion(context, AppMotion.rapido),
        curve: AppMotion.curvaCambio,
        constraints: const BoxConstraints(minHeight: 44),
        decoration: BoxDecoration(
          color: elegido ? AppColors.acento : Colors.white,
          borderRadius: radio,
          border:
              Border.all(color: elegido ? AppColors.acento : AppColors.filo),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: alPulsar,
            borderRadius: radio,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: 10),
              child: AnimatedDefaultTextStyle(
                duration: AppMotion.duracion(context, AppMotion.rapido),
                curve: AppMotion.curvaCambio,
                style: AppTextStyles.cuerpo.copyWith(
                  fontWeight: FontWeight.w600,
                  color: elegido ? Colors.white : AppColors.textPrimary,
                ),
                child: Text(texto),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Una fila de la tarjeta de detalles: el rótulo a la izquierda, lo elegido
/// a la derecha y la flecha de que abre algo. Sin [alPulsar] espera, apagada.
class _Fila extends StatelessWidget {
  const _Fila({
    super.key,
    required this.rotulo,
    required this.leido,
    required this.valor,
    required this.alPulsar,
  });

  final String rotulo;

  /// Lo que dice el lector de pantalla por [valor].
  final String leido;
  final Widget valor;
  final VoidCallback? alPulsar;

  @override
  Widget build(BuildContext context) {
    final activa = alPulsar != null;
    return Semantics(
      container: true,
      button: true,
      enabled: activa,
      label: rotulo,
      value: leido,
      onTap: alPulsar,
      excludeSemantics: true,
      child: InkWell(
        onTap: alPulsar,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, 12, 12, 12),
            child: Row(
              children: [
                Text(
                  rotulo,
                  style: AppTextStyles.cuerpo.copyWith(
                    color: activa
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: valor,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 22,
                  color: activa ? AppColors.textSecondary : AppColors.divider,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Una hoja de abajo, blanca y con su asa, para elegir un detalle sin salir
/// del formulario (el mensaje a medio escribir se queda donde está). Devuelve
/// lo elegido, o nulo si se cierra sin elegir.
Future<T?> _abrirHoja<T>(
  BuildContext context, {
  required String titulo,
  required Widget cuerpo,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius:
          BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
    ),
    clipBehavior: Clip.antiAlias,
    builder: (context) => ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 10),
          const SheetHandle(),
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, 18, AppSpacing.lg, AppSpacing.sm),
            child: Semantics(
              header: true,
              child: Text(
                titulo,
                style:
                    AppTextStyles.titulo.copyWith(color: AppColors.textPrimary),
              ),
            ),
          ),
          Flexible(child: cuerpo),
        ],
      ),
    ),
  );
}

/// Lo que dice una hoja cuando no tiene filas: cargando, vacía o con error.
class _NotaHoja extends StatelessWidget {
  const _NotaHoja(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.lg),
        child: Text(
          texto,
          style: AppTextStyles.cuerpo.copyWith(color: AppColors.textBody),
        ),
      );
}

/// Una fila de una hoja: lo que se elige y, si ya estaba elegido, su marca.
class _FilaHoja extends StatelessWidget {
  const _FilaHoja({
    super.key,
    required this.leido,
    required this.elegida,
    required this.alPulsar,
    required this.child,
  });

  final String leido;
  final bool elegida;
  final VoidCallback alPulsar;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: elegida,
      label: leido,
      onTap: alPulsar,
      excludeSemantics: true,
      child: InkWell(
        onTap: alPulsar,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Align(alignment: Alignment.centerLeft, child: child),
                ),
                if (elegida)
                  const Icon(Icons.check_rounded,
                      size: 22, color: AppColors.acento),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Las rutas, bajo el nombre de su empresa.
class _HojaRutas extends ConsumerWidget {
  const _HojaRutas({required this.elegida});

  final String? elegida;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(companiesProvider).when(
          loading: () => const _NotaHoja('Cargando las rutas…'),
          error: (_, __) => const _NotaHoja(
              'No se pudieron cargar las rutas. Revisa tu conexión.'),
          data: (empresas) => ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            children: [
              for (final empresa in empresas) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg, 12, AppSpacing.lg, AppSpacing.xs),
                  child: Semantics(
                    header: true,
                    child: Text(
                      empresa.name,
                      style: AppTextStyles.etiqueta
                          .copyWith(color: AppColors.textSecondary),
                    ),
                  ),
                ),
                _RutasDeEmpresa(empresa: empresa.id, elegida: elegida),
              ],
            ],
          ),
        );
  }
}

class _RutasDeEmpresa extends ConsumerWidget {
  const _RutasDeEmpresa({required this.empresa, required this.elegida});

  final String empresa;
  final String? elegida;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(routesByCompanyProvider(empresa)).when(
          loading: () => const _NotaHoja('Cargando…'),
          error: (_, __) => const _NotaHoja('No se pudieron cargar sus rutas.'),
          data: (rutas) => Column(
            children: [
              for (final ruta in rutas)
                _FilaHoja(
                  key: ValueKey('queja_ruta_${ruta.id}'),
                  leido: ruta.name,
                  elegida: ruta.id == elegida,
                  alPulsar: () => Navigator.of(context).pop(ruta),
                  child: Row(
                    children: [
                      if (codigoRuta(ruta.name) case final codigo?) ...[
                        FichaRuta(
                          codigo,
                          color: colorFicha(companyId: ruta.companyId),
                          lado: 36,
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: Text(
                          nombreSinCodigo(ruta.name) ?? ruta.name,
                          style: AppTextStyles.cuerpo
                              .copyWith(color: AppColors.textPrimary),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
  }
}

/// Los buses de la ruta que están en línea ahora, por placa. Mira la misma
/// fuente que el mapa: si la ruta es la del mapa, no abre otra suscripción.
class _HojaBuses extends ConsumerWidget {
  const _HojaBuses({required this.rutaId, required this.elegido});

  final String rutaId;
  final String? elegido;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(busPositionsSourceProvider(rutaId)).when(
          loading: () => const _NotaHoja('Buscando los buses de la ruta…'),
          error: (_, __) => const _NotaHoja('No se pudieron cargar los buses.'),
          data: (posiciones) {
            final buses = {for (final p in posiciones) p.busId}.toList()
              ..sort((a, b) => busPlaca(a).compareTo(busPlaca(b)));
            return ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              children: [
                if (buses.isEmpty)
                  const _NotaHoja('No hay buses de esta ruta en línea ahora.'),
                for (final bus in buses)
                  _FilaHoja(
                    key: ValueKey('queja_bus_$bus'),
                    leido: 'placa ${busPlaca(bus)}',
                    elegida: bus == elegido,
                    alPulsar: () => Navigator.of(context).pop(bus),
                    child: PlacaBus(busPlaca(bus)),
                  ),
                // Para soltar el que estaba, o seguir sin decir cuál.
                if (buses.isNotEmpty || elegido != null)
                  _FilaHoja(
                    key: const ValueKey('queja_bus_ninguno'),
                    leido: 'No sé cuál',
                    elegida: false,
                    alPulsar: () => Navigator.of(context).pop(''),
                    child: Text(
                      'No sé cuál',
                      style: AppTextStyles.cuerpo
                          .copyWith(color: AppColors.textSecondary),
                    ),
                  ),
              ],
            );
          },
        );
  }
}

/// El día y la hora en dos ruedas, como la de la distancia del aviso: de hoy
/// hasta seis días atrás, y sin horas que todavía no llegan.
class _HojaHora extends StatefulWidget {
  const _HojaHora({required this.inicial});

  final DateTime? inicial;

  @override
  State<_HojaHora> createState() => _HojaHoraState();
}

class _HojaHoraState extends State<_HojaHora> {
  final _ahora = DateTime.now();
  late int _dia;
  late int _hora;
  late final FixedExtentScrollController _ruedaDia;
  late final FixedExtentScrollController _ruedaHora;

  @override
  void initState() {
    super.initState();
    final inicial = widget.inicial ?? _ahora;
    final hoy = DateTime(_ahora.year, _ahora.month, _ahora.day);
    final atras = hoy
        .difference(DateTime(inicial.year, inicial.month, inicial.day))
        .inHours;
    _dia = (atras / 24).round().clamp(0, _diasAtras - 1);
    _hora = inicial.hour.clamp(0, _ultimaHora);
    _ruedaDia = FixedExtentScrollController(initialItem: _dia);
    _ruedaHora = FixedExtentScrollController(initialItem: _hora);
  }

  @override
  void dispose() {
    _ruedaDia.dispose();
    _ruedaHora.dispose();
    super.dispose();
  }

  /// Hoy solo se ofrece hasta la hora en curso.
  int get _ultimaHora => _dia == 0 ? _ahora.hour : 23;

  void _alCambiarDia(int dia) {
    setState(() => _dia = dia);
    if (_hora <= _ultimaHora) return;
    // De ayer a las 9 p. m. a hoy a las 3: la rueda baja a la última que hay.
    _hora = _ultimaHora;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _ruedaHora.jumpToItem(_hora);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                flex: 3,
                child: _Rueda(
                  key: const ValueKey('queja_hora_dia'),
                  rueda: _ruedaDia,
                  rotulos: [
                    for (var d = 0; d < _diasAtras; d++) _diaLegible(d, _ahora),
                  ],
                  // Las dos ruedas comparten una sola franja: cada una la
                  // deja abierta por donde toca a la otra.
                  cierraAlFinal: false,
                  alCambiar: _alCambiarDia,
                ),
              ),
              Expanded(
                flex: 2,
                child: _Rueda(
                  key: const ValueKey('queja_hora_hora'),
                  rueda: _ruedaHora,
                  rotulos: [
                    for (var h = 0; h <= _ultimaHora; h++) _horaLegible(h),
                  ],
                  cierraAlInicio: false,
                  alCambiar: (hora) => _hora = hora,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: 56,
            child: FilledButton(
              key: const ValueKey('queja_hora_listo'),
              onPressed: () => Navigator.of(context).pop(DateTime(
                  _ahora.year, _ahora.month, _ahora.day - _dia, _hora)),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.textPrimary,
                textStyle: AppTextStyles.boton,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
              child: const Text('Listo'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Una rueda con el aspecto de la de la distancia del aviso
/// (`rueda_distancia.dart`): cinco filas apretadas, la del medio en su
/// franja verde y las de los bordes desvanecidas.
class _Rueda extends StatelessWidget {
  const _Rueda({
    super.key,
    required this.rueda,
    required this.rotulos,
    required this.alCambiar,
    this.cierraAlInicio = true,
    this.cierraAlFinal = true,
  });

  final FixedExtentScrollController rueda;
  final List<String> rotulos;
  final ValueChanged<int> alCambiar;
  final bool cierraAlInicio;
  final bool cierraAlFinal;

  static const _filas = 5;
  static const _apriete = 1.45;

  @override
  Widget build(BuildContext context) {
    // La fila crece con el texto del sistema, para que no se monte.
    final fila = 10 + MediaQuery.textScalerOf(context).scale(30);
    const borde = _apriete / _filas;
    return SizedBox(
      height: fila * _filas / _apriete,
      child: ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (caja) => const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0x26000000),
            Color(0xFF000000),
            Color(0xFF000000),
            Color(0x26000000),
          ],
          stops: [0, borde, 1 - borde, 1],
        ).createShader(caja),
        child: CupertinoPicker(
          scrollController: rueda,
          itemExtent: fila,
          squeeze: _apriete,
          useMagnifier: true,
          magnification: 1.08,
          selectionOverlay: CupertinoPickerDefaultSelectionOverlay(
            background: franjaRuedaDistancia,
            capStartEdge: cierraAlInicio,
            capEndEdge: cierraAlFinal,
          ),
          onSelectedItemChanged: (indice) {
            // En iOS la rueda ya da su toque; en Android se lo damos.
            if (defaultTargetPlatform != TargetPlatform.iOS) {
              HapticFeedback.selectionClick();
            }
            alCambiar(indice);
          },
          children: [
            for (final rotulo in rotulos)
              Center(
                child: Text(
                  rotulo,
                  style: AppTextStyles.titulo.copyWith(
                    color: AppColors.textPrimary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
