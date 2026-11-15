// «¿A dónde vas?»: el planificador (docs/viaje-completo.md, sección 3.3).
//
// Arriba, los dos puntos del viaje, como en Citymapper o Transit: «Desde»
// arranca en la ubicación de la persona y «A» espera que se busque o se
// toque el mapa. Abajo, las opciones, cada una con su tira de tramos y, a la
// derecha, a cuánto viene el bus, en metros como la hoja del mapa (la app
// dice distancias, no minutos). La opción elegida se dibuja en el mapa, que
// la enmarca entre la tarjeta de arriba y el panel de abajo.
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

import '../../core/providers/red_provider.dart';
import '../../core/utils/bus_labels.dart';
import '../../core/utils/color_empresa.dart';
import '../../core/utils/distancia.dart';
import '../../core/widgets/aviso.dart';
import '../../core/widgets/ficha_ruta.dart';
import '../../core/widgets/sheet_handle.dart';
import '../../core/widgets/tamano_animado.dart';
import '../map/presentation/providers/estilo_mapa_provider.dart';
import '../map/presentation/providers/user_location_provider.dart';
import '../map/presentation/utils/camera_fit.dart' show FitBounds;
import '../map/presentation/utils/map_constants.dart';
import 'capa_viaje.dart';
import 'lugares_del_viaje.dart';
import 'planificador.dart';
import 'trazo_del_viaje.dart';

/// Cuántas opciones se muestran. Más de tres ya no se comparan de un
/// vistazo, y la cuarta casi siempre es la tercera con otra caminata.
const maxOpcionesVisibles = 3;

/// Cuál de los dos puntos se está poniendo.
enum ExtremoDelViaje { origen, destino }

/// El papel del mapa retocado (`estilo_retocado.dart`): lo que se ve
/// mientras baja el estilo, sin el salto de un fondo gris a otro.
const _papel = Color(0xFFF4F2EE);

/// El azul de botón al 10 % sobre blanco: el medallón del punto de origen y
/// de la entrada «¿A dónde vas?». El ícono en `acento` queda a 6,2:1.
const tintaAcento = Color(0xFFE9EEF6);

class ViajeScreen extends ConsumerStatefulWidget {
  const ViajeScreen({super.key});

  @override
  ConsumerState<ViajeScreen> createState() => _ViajeScreenState();
}

class _ViajeScreenState extends ConsumerState<ViajeScreen> {
  final _capa = CapaViaje();
  final _tarjeta = GlobalKey();
  final _panel = GlobalKey();
  MapLibreMapController? _mapa;

  /// El punto que espera un toque en el mapa, tras «Elegir en el mapa».
  ExtremoDelViaje? _poniendo;

  @override
  Widget build(BuildContext context) {
    ref.listen(planificadorProvider, (_, __) => _redibujar());
    ref.listen(planProvider, (_, __) => _redibujar());
    final estilo = kIsWeb ? null : ref.watch(estiloMapaProvider).value;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: _papel,
        body: Stack(
          children: [
            Positioned.fill(
              child: estilo == null
                  ? const ColoredBox(color: _papel)
                  : _mapaDelViaje(estilo),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
                  child: MediaQuery.withClampedTextScaling(
                    maxScaleFactor: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _TarjetaDePuntos(
                          key: _tarjeta,
                          alTocar: _abrirBuscador,
                        ),
                        AnimatedSwitcher(
                          duration: AppMotion.rapido,
                          switchInCurve: AppMotion.curvaEntrada,
                          switchOutCurve: AppMotion.curvaEntrada,
                          child: _poniendo == null
                              ? const SizedBox.shrink()
                              : Padding(
                                  padding:
                                      const EdgeInsets.only(top: AppSpacing.sm),
                                  child: _AvisoDeToque(
                                    extremo: _poniendo!,
                                    alCancelar: () =>
                                        setState(() => _poniendo = null),
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: MediaQuery.withClampedTextScaling(
                maxScaleFactor: 2,
                child: _PanelDeOpciones(key: _panel, alIr: _ir),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mapaDelViaje(String estilo) {
    return MapLibreMap(
      onMapCreated: (c) => _mapa = c,
      onStyleLoadedCallback: () async {
        final c = _mapa;
        if (c == null) return;
        _capa.olvidar();
        try {
          await _capa.instalar(c, bajoRotulos: primeraCapaDeRotulos(estilo));
        } catch (e) {
          debugPrint('viaje: no se pudieron poner las capas: $e');
          return;
        }
        await _redibujar();
      },
      featureTapsTriggersMapClick: true,
      styleString: estilo,
      initialCameraPosition: const CameraPosition(
        target: LatLng(MapConstants.areaCentroLat, MapConstants.areaCentroLon),
        zoom: MapConstants.zoomMinimo,
      ),
      compassEnabled: false,
      // La atribución va en Info, como en el mapa (`map_widget.dart`).
      attributionButtonPosition: AttributionButtonPosition.bottomLeft,
      attributionButtonMargins: const math.Point(-1000, -1000),
      myLocationEnabled: false,
      rotateGesturesEnabled: true,
      tiltGesturesEnabled: false,
      minMaxZoomPreference: const MinMaxZoomPreference(
          MapConstants.zoomMinimo, MapConstants.zoomMaximo),
      cameraTargetBounds: CameraTargetBounds(LatLngBounds(
        southwest:
            const LatLng(MapConstants.areaSurLat, MapConstants.areaOesteLon),
        northeast:
            const LatLng(MapConstants.areaNorteLat, MapConstants.areaEsteLon),
      )),
      onMapClick: (_, latLng) => _alTocarElMapa(latLng),
    );
  }

  /// Tocar el mapa pone un punto: el que se pidió con «Elegir en el mapa»,
  /// el origen si es lo único que falta, y si no, el destino (lo que más se
  /// cambia).
  void _alTocarElMapa(LatLng latLng) {
    final lugar = Lugar(
      punto: GeoPoint(lat: latLng.latitude, lon: latLng.longitude),
      origen: OrigenLugar.pin,
    );
    final planificacion = ref.read(planificadorProvider);
    final extremo = _poniendo ??
        (planificacion.origen == null && planificacion.destino != null
            ? ExtremoDelViaje.origen
            : ExtremoDelViaje.destino);
    HapticFeedback.selectionClick();
    setState(() => _poniendo = null);
    _poner(extremo, lugar);
  }

  void _poner(ExtremoDelViaje extremo, Lugar lugar) {
    final planificador = ref.read(planificadorProvider.notifier);
    extremo == ExtremoDelViaje.origen
        ? planificador.ponerOrigen(lugar)
        : planificador.ponerDestino(lugar);
  }

  Future<void> _abrirBuscador(ExtremoDelViaje extremo) async {
    setState(() => _poniendo = null);
    final eleccion = await abrirBuscadorDeLugar(context, ref, extremo);
    if (!mounted || eleccion == null) return;
    switch (eleccion) {
      case EleccionEnElMapa():
        setState(() => _poniendo = extremo);
      // Los sitios ya quedan en los recientes: los guarda `BuscaLugar`.
      case EleccionDeLugar(:final lugar):
        _poner(extremo, lugar);
    }
  }

  Future<void> _ir(Viaje viaje) async {
    HapticFeedback.mediumImpact();
    final listo = await ref.read(irAlViajeProvider)(viaje);
    if (!mounted) return;
    if (listo) {
      context.pop();
    } else {
      mostrarAviso(
        context,
        'No se pudo abrir la ruta. Revisa tu conexión.',
        icono: Icons.wifi_off_rounded,
      );
    }
  }

  /// Pone en el mapa lo que hay: la opción elegida entera, o los puntos
  /// sueltos mientras falte el otro. La cámara se mueve después del cuadro,
  /// cuando la tarjeta y el panel ya tienen su alto.
  Future<void> _redibujar() async {
    final planificacion = ref.read(planificadorProvider);
    final plan = ref.read(planProvider)?.valueOrNull;
    final red = ref.read(redDeRutasProvider).valueOrNull;
    TrazoDelViaje? trazo;
    if (plan is PlanConViajes && red != null) {
      final i = planificacion.elegida.clamp(0, plan.viajes.length - 1);
      trazo = trazarViaje(plan.viajes[i], red);
    }
    final origen = planificacion.origen?.punto;
    final destino = planificacion.destino?.punto;
    await _capa.dibujar(trazo: trazo, origen: origen, destino: destino);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (trazo != null) {
        _enmarcar(trazo.caja);
      } else if (origen != null && destino != null) {
        _enmarcar(_cajaDe([origen, destino]));
      } else if ((origen ?? destino) case final solo?) {
        _mapa?.animateCamera(
          CameraUpdate.newLatLngZoom(LatLng(solo.lat, solo.lon), 15),
          duration: AppMotion.normal,
        );
      }
    });
  }

  void _enmarcar(FitBounds caja) {
    final mapa = _mapa;
    if (mapa == null) return;
    final alto = MediaQuery.sizeOf(context).height;
    final tarjeta = _bordeInferior(_tarjeta) ?? 160;
    final panel = _bordeSuperior(_panel) ?? alto * 0.55;
    final update = CameraUpdate.newLatLngBounds(
      LatLngBounds(
        southwest: LatLng(caja.minLat, caja.minLon),
        northeast: LatLng(caja.maxLat, caja.maxLon),
      ),
      left: 32,
      right: 32,
      top: tarjeta + AppSpacing.lg,
      bottom: alto - panel + AppSpacing.lg,
    );
    if (AppMotion.reducido(context)) {
      mapa.moveCamera(update);
    } else {
      mapa.animateCamera(update, duration: AppMotion.normal);
    }
  }

  double? _bordeInferior(GlobalKey llave) {
    final caja = llave.currentContext?.findRenderObject() as RenderBox?;
    if (caja == null || !caja.hasSize) return null;
    return caja.localToGlobal(Offset(0, caja.size.height)).dy;
  }

  double? _bordeSuperior(GlobalKey llave) {
    final caja = llave.currentContext?.findRenderObject() as RenderBox?;
    if (caja == null || !caja.hasSize) return null;
    return caja.localToGlobal(Offset.zero).dy;
  }
}

FitBounds _cajaDe(List<GeoPoint> puntos) => (
      minLat: puntos.map((p) => p.lat).reduce(math.min),
      minLon: puntos.map((p) => p.lon).reduce(math.min),
      maxLat: puntos.map((p) => p.lat).reduce(math.max),
      maxLon: puntos.map((p) => p.lon).reduce(math.max),
    );

/// Lo que devuelve el buscador: un lugar, o que se quiere tocar el mapa.
sealed class EleccionDelBuscador {
  const EleccionDelBuscador();
}

class EleccionDeLugar extends EleccionDelBuscador {
  const EleccionDeLugar(this.lugar);
  final Lugar lugar;
}

class EleccionEnElMapa extends EleccionDelBuscador {
  const EleccionEnElMapa();
}

/// La hoja con el buscador (D25), la misma forma que la del Buzón: blanca,
/// con su asa y su título, hasta el 85 % de la pantalla.
Future<EleccionDelBuscador?> abrirBuscadorDeLugar(
  BuildContext context,
  WidgetRef ref,
  ExtremoDelViaje extremo,
) {
  final ubicacion = ref.read(userLocationProvider);
  final gps = switch (ubicacion) {
    UserLocationState(:final lat?, :final lon?, mode: UserLocationMode.gps) =>
      Lugar(punto: GeoPoint(lat: lat, lon: lon), origen: OrigenLugar.gps),
    _ => null,
  };
  final planificacion = ref.read(planificadorProvider);
  final otro = extremo == ExtremoDelViaje.origen
      ? planificacion.destino
      : planificacion.origen;
  // «Tu ubicación» solo si hay GPS y no es ya el otro punto del viaje.
  final ofreceGps = gps != null && otro?.origen != OrigenLugar.gps;
  final sesgo = gps?.punto ?? otro?.punto;

  return showModalBottomSheet<EleccionDelBuscador>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.surface,
    clipBehavior: Clip.antiAlias,
    shape: const RoundedRectangleBorder(
      borderRadius:
          BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
    ),
    builder: (hoja) => ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(hoja).height * 0.85,
      ),
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(hoja).bottom,
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
                  extremo == ExtremoDelViaje.origen
                      ? '¿Desde dónde sales?'
                      : '¿A dónde vas?',
                  style: AppTextStyles.titulo
                      .copyWith(color: AppColors.textPrimary),
                ),
              ),
            ),
            Flexible(
              child: Consumer(
                builder: (context, ref, _) {
                  final buscador = ref.watch(buscadorDeLugaresProvider);
                  return switch (buscador) {
                    AsyncData(:final value) => BuscaLugar(
                        buscador: value,
                        recientes: ref.read(recientesDeLugaresProvider),
                        autofocus: true,
                        sesgo: sesgo,
                        alElegir: (lugar) =>
                            Navigator.of(hoja).pop(EleccionDeLugar(lugar)),
                        alUsarUbicacion: ofreceGps
                            ? () => Navigator.of(hoja).pop(EleccionDeLugar(gps))
                            : null,
                        alElegirEnMapa: () =>
                            Navigator.of(hoja).pop(const EleccionEnElMapa()),
                      ),
                    AsyncError() => Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Text(
                          'No se pudo abrir el buscador.',
                          style: AppTextStyles.cuerpo
                              .copyWith(color: AppColors.textBody),
                        ),
                      ),
                    _ => const Padding(
                        padding: EdgeInsets.all(AppSpacing.xl),
                        child: Center(child: IndicadorCarga()),
                      ),
                  };
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Cómo se nombra un punto en la tarjeta de arriba.
String nombreDelLugar(Lugar lugar) => switch (lugar.origen) {
      OrigenLugar.gps => 'Tu ubicación',
      OrigenLugar.pin => 'Punto en el mapa',
      OrigenLugar.sitio => lugar.nombre ?? 'Punto en el mapa',
    };

/// La tarjeta blanca de arriba: volver, los dos puntos unidos por la línea
/// punteada del viaje y el botón de darle la vuelta.
class _TarjetaDePuntos extends ConsumerWidget {
  const _TarjetaDePuntos({super.key, required this.alTocar});

  final ValueChanged<ExtremoDelViaje> alTocar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(planificadorProvider);
    final puedeInvertir = p.origen != null || p.destino != null;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.hairline),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDeep.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 6, 4, 6),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Volver',
              onPressed: () => context.pop(),
              icon: const Icon(Icons.arrow_back_rounded,
                  color: AppColors.textPrimary),
            ),
            Expanded(
              child: Column(
                children: [
                  _FilaDePunto(
                    llave: const ValueKey('viaje-desde'),
                    rotulo: 'Desde',
                    lugar: p.origen,
                    vacio: '¿Desde dónde?',
                    marca: const _Marca.origen(),
                    alTocar: () => alTocar(ExtremoDelViaje.origen),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(left: 44),
                    child: Divider(height: 1, color: AppColors.hairline),
                  ),
                  _FilaDePunto(
                    llave: const ValueKey('viaje-a'),
                    rotulo: 'A',
                    lugar: p.destino,
                    vacio: 'Toca el mapa o busca',
                    marca: const _Marca.destino(),
                    alTocar: () => alTocar(ExtremoDelViaje.destino),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Invertir el viaje',
              onPressed: puedeInvertir
                  ? () {
                      HapticFeedback.selectionClick();
                      ref.read(planificadorProvider.notifier).invertir();
                    }
                  : null,
              icon: const Icon(Icons.swap_vert_rounded),
              color: AppColors.acento,
              disabledColor: AppColors.textDisabled,
            ),
          ],
        ),
      ),
    );
  }
}

/// El punto de cada fila: azul el origen, tinta el destino, como en el mapa
/// (`CapaViaje`).
class _Marca extends StatelessWidget {
  const _Marca.origen() : destino = false;
  const _Marca.destino() : destino = true;

  final bool destino;

  @override
  Widget build(BuildContext context) => Container(
        width: destino ? 12 : 11,
        height: destino ? 12 : 11,
        decoration: BoxDecoration(
          color: destino ? AppColors.ink : AppColors.acento,
          shape: destino ? BoxShape.rectangle : BoxShape.circle,
          borderRadius: destino ? BorderRadius.circular(AppRadius.marca) : null,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(
              color: (destino ? AppColors.ink : AppColors.acento)
                  .withValues(alpha: 0.35),
              blurRadius: 0,
              spreadRadius: 1,
            ),
          ],
        ),
      );
}

class _FilaDePunto extends StatelessWidget {
  const _FilaDePunto({
    required this.llave,
    required this.rotulo,
    required this.lugar,
    required this.vacio,
    required this.marca,
    required this.alTocar,
  });

  final Key llave;
  final String rotulo;
  final Lugar? lugar;
  final String vacio;
  final Widget marca;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    final nombre = lugar == null ? null : nombreDelLugar(lugar!);
    return Semantics(
      button: true,
      label: '$rotulo: ${nombre ?? vacio}',
      excludeSemantics: true,
      child: InkWell(
        key: llave,
        onTap: alTocar,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                SizedBox(width: 20, child: Center(child: marca)),
                const SizedBox(width: AppSpacing.sm + 4),
                SizedBox(
                  width: 52,
                  child: Text(
                    rotulo,
                    style: AppTextStyles.etiqueta
                        .copyWith(color: AppColors.textSecondary),
                  ),
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: AppMotion.rapido,
                    switchInCurve: AppMotion.curvaEntrada,
                    switchOutCurve: AppMotion.curvaEntrada,
                    layoutBuilder: (actual, previos) => Stack(
                      alignment: Alignment.centerLeft,
                      children: [...previos, if (actual != null) actual],
                    ),
                    child: Text(
                      nombre ?? vacio,
                      key: ValueKey(nombre ?? vacio),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: nombre == null
                          ? AppTextStyles.cuerpo
                              .copyWith(color: AppColors.textSecondary)
                          : AppTextStyles.cuerpoFuerte.copyWith(
                              color: lugar!.origen == OrigenLugar.gps
                                  ? AppColors.acento
                                  : AppColors.textPrimary,
                            ),
                    ),
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

/// «Toca el mapa para poner el destino», con su «Cancelar».
class _AvisoDeToque extends StatelessWidget {
  const _AvisoDeToque({required this.extremo, required this.alCancelar});

  final ExtremoDelViaje extremo;
  final VoidCallback alCancelar;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.ink,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryDeep.withValues(alpha: 0.18),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.touch_app_rounded,
                  size: 18, color: Colors.white),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Text(
                  extremo == ExtremoDelViaje.origen
                      ? 'Toca el mapa donde sales'
                      : 'Toca el mapa a donde vas',
                  style: AppTextStyles.etiqueta.copyWith(color: Colors.white),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              TextButton(
                onPressed: alCancelar,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  minimumSize: const Size(44, 36),
                  shape: const StadiumBorder(),
                ),
                child: Text(
                  'Cancelar',
                  style: AppTextStyles.etiqueta.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// El panel blanco de abajo: lo que falta, lo que se está buscando o las
/// opciones con su «Ir».
class _PanelDeOpciones extends ConsumerWidget {
  const _PanelDeOpciones({super.key, required this.alIr});

  final ValueChanged<Viaje> alIr;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(planificadorProvider);
    final plan = ref.watch(planProvider);
    final hayRed = ref.watch(hayRedProvider).valueOrNull ?? true;
    final abajo = MediaQuery.paddingOf(context).bottom;

    final Widget cuerpo = switch ((p.origen, p.destino, plan)) {
      (null, _, _) => const _Estado(
          key: ValueKey('sin-origen'),
          icono: Icons.my_location_rounded,
          titulo: '¿Desde dónde sales?',
          detalle: 'Búscalo arriba o toca el mapa.',
        ),
      (_, null, _) => const _Estado(
          key: ValueKey('sin-destino'),
          icono: Icons.place_rounded,
          titulo: '¿A dónde vas?',
          detalle: 'Busca un barrio, una calle o un sitio, o toca el mapa.',
        ),
      (_, _, AsyncError()) => _Estado(
          key: const ValueKey('error'),
          icono: Icons.cloud_off_rounded,
          titulo: 'No se pudieron cargar las rutas',
          detalle: 'Revisa tu conexión y vuelve a intentarlo.',
          accion: 'Reintentar',
          alAccionar: () => ref.invalidate(redDeRutasProvider),
        ),
      (_, _, AsyncData(value: PlanMuyCerca(:final metros))) => _Estado(
          key: const ValueKey('muy-cerca'),
          icono: Icons.directions_walk_rounded,
          titulo: 'Se llega antes a pie',
          detalle: 'Son ${caminataHablada(metros).replaceFirst(' a pie', '')}'
              ', más cerca que cualquier bus.',
        ),
      (_, _, AsyncData(value: PlanSinRuta() && final sin)) => _Estado(
          key: const ValueKey('sin-ruta'),
          icono: Icons.alt_route_rounded,
          titulo: 'Ninguna ruta pasa cerca de los dos puntos',
          detalle: switch ((sin.pasaCercaDelOrigen, sin.pasaCercaDelDestino)) {
            (true, false) => 'Hay rutas cerca de donde sales, pero no '
                'llegan cerca de a donde vas. Prueba con otro punto.',
            (false, true) => 'Hay rutas cerca de a donde vas, pero no pasan '
                'cerca de donde sales. Prueba con otro punto.',
            _ => 'Prueba con un punto más cerca de una avenida.',
          },
        ),
      (_, _, AsyncData(value: PlanConViajes(:final viajes))) => _Opciones(
          key: const ValueKey('opciones'),
          viajes: viajes.take(maxOpcionesVisibles).toList(),
          elegida: p.elegida,
          alIr: alIr,
        ),
      _ => const _OpcionesCargando(key: ValueKey('cargando')),
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDeep.withValues(alpha: 0.10),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.52,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 10),
            const SheetHandle(),
            if (!hayRed)
              const Padding(
                padding: EdgeInsets.fromLTRB(
                    AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 0),
                child: _NotaSinRed(),
              ),
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                    AppSpacing.md, AppSpacing.sm, AppSpacing.md, abajo + 12),
                child: TamanoAnimado(
                  duracion: AppMotion.normal,
                  alineacion: Alignment.topCenter,
                  child: AnimatedSwitcher(
                    duration: AppMotion.rapido,
                    switchInCurve: AppMotion.curvaEntrada,
                    switchOutCurve: AppMotion.curvaEntrada,
                    layoutBuilder: (actual, previos) => Stack(
                      alignment: Alignment.topCenter,
                      children: [...previos, if (actual != null) actual],
                    ),
                    child: cuerpo,
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

class _NotaSinRed extends StatelessWidget {
  const _NotaSinRed();

  @override
  Widget build(BuildContext context) => Row(
        children: [
          const Icon(Icons.wifi_off_rounded,
              size: 16, color: AppColors.textSecondary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Sin internet: no se ven los buses en vivo.',
              style: AppTextStyles.pie.copyWith(color: AppColors.textSecondary),
            ),
          ),
        ],
      );
}

/// Un estado sin opciones: su ícono en el medallón azul, el título y lo
/// que se puede hacer.
class _Estado extends StatelessWidget {
  const _Estado({
    super.key,
    required this.icono,
    required this.titulo,
    required this.detalle,
    this.accion,
    this.alAccionar,
  });

  final IconData icono;
  final String titulo;
  final String detalle;
  final String? accion;
  final VoidCallback? alAccionar;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.sm, AppSpacing.sm, AppSpacing.sm, AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: tintaAcento,
              shape: BoxShape.circle,
            ),
            child: Icon(icono, size: 22, color: AppColors.acento),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 2),
                Semantics(
                  header: true,
                  child: Text(
                    titulo,
                    style: AppTextStyles.subtitulo
                        .copyWith(color: AppColors.textPrimary),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  detalle,
                  style:
                      AppTextStyles.cuerpo.copyWith(color: AppColors.textBody),
                ),
                if (accion != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  FilledButton(
                    onPressed: alAccionar,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.acento,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 44),
                      shape: const StadiumBorder(),
                      // En textStyle y no en el Text: así el blanco del
                      // botón manda sobre la tinta que trae el estilo.
                      textStyle: AppTextStyles.boton,
                    ),
                    child: Text(accion!),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Las tarjetas fantasma con la forma de las de verdad.
class _OpcionesCargando extends StatelessWidget {
  const _OpcionesCargando({super.key});

  @override
  Widget build(BuildContext context) {
    Widget barra(double ancho, double alto) => Container(
          width: ancho,
          height: alto,
          decoration: BoxDecoration(
            color: AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(AppRadius.xs),
          ),
        );
    return CargaFantasma(
      semanticsLabel: 'Buscando opciones',
      child: Column(
        children: [
          for (var i = 0; i < 2; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: AppColors.filo),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            barra(20, 20),
                            const SizedBox(width: 10),
                            barra(28, 28),
                            const SizedBox(width: 10),
                            barra(20, 20),
                          ]),
                          const SizedBox(height: 12),
                          barra(140, 12),
                          const SizedBox(height: 8),
                          barra(180, 12),
                        ],
                      ),
                    ),
                    barra(48, 30),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Opciones extends ConsumerWidget {
  const _Opciones({
    super.key,
    required this.viajes,
    required this.elegida,
    required this.alIr,
  });

  final List<Viaje> viajes;
  final int elegida;
  final ValueChanged<Viaje> alIr;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final i = elegida.clamp(0, viajes.length - 1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var n = 0; n < viajes.length; n++)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: TarjetaDeOpcion(
              key: ValueKey('opcion-$n'),
              viaje: viajes[n],
              elegida: n == i,
              alTocar: () {
                if (n == i) return;
                HapticFeedback.selectionClick();
                ref.read(planificadorProvider.notifier).elegir(n);
              },
            ),
          ),
        const SizedBox(height: AppSpacing.xs),
        FilledButton.icon(
          key: const ValueKey('viaje-ir'),
          onPressed: () => alIr(viajes[i]),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.acento,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(52),
            shape: const StadiumBorder(),
            textStyle: AppTextStyles.boton,
          ),
          icon: const Icon(Icons.navigation_rounded, size: 20),
          label: const Text('Ir'),
        ),
      ],
    );
  }
}

/// Una opción: la tira de tramos, la caminata, cuándo llega el bus y, a la
/// derecha, a cuánto viene.
class TarjetaDeOpcion extends ConsumerWidget {
  const TarjetaDeOpcion({
    super.key,
    required this.viaje,
    required this.elegida,
    required this.alTocar,
  });

  final Viaje viaje;
  final bool elegida;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primero = viaje.enBus.first;
    final bus = ref.watch(busQueVieneProvider(primero));
    final ritmo = ref.watch(ritmoDeRutaProvider(primero.ruta));
    final nombres = {
      for (final r
          in ref.watch(rutasSobusaProvider).valueOrNull ?? const <RutaSobusa>[])
        r.routeId: r.name,
    };
    final rango =
        bus == null ? null : ritmo?.paraRecorrer(bus.metrosHastaLaSubida);

    final String? llegada;
    if (bus == null) {
      llegada = null;
    } else if (rango == null) {
      llegada = null;
    } else {
      llegada = textoDeLlegada(DateTime.now(), rango);
    }

    final cifra =
        bus == null ? null : distanciaPartes(bus.metrosHastaLaSubida, '');

    return Semantics(
      button: true,
      selected: elegida,
      child: AnimatedContainer(
        duration: AppMotion.rapido,
        curve: AppMotion.curvaCambio,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: elegida ? AppColors.acento : AppColors.filo,
            width: elegida ? 2 : 1,
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: alTocar,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: Padding(
              // Con el filo de 2 la tarjeta elegida no se mueve: el padding
              // se come el punto de más.
              padding: EdgeInsets.all(elegida ? 13 : 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _TiraDeTramos(viaje: viaje, nombres: nombres),
                        const SizedBox(height: 10),
                        Text(
                          _resumen(viaje, nombres),
                          style: AppTextStyles.cuerpoFuerte
                              .copyWith(color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          caminataHablada(viaje.caminataTotal),
                          style: AppTextStyles.pie
                              .copyWith(color: AppColors.textBody),
                        ),
                        const SizedBox(height: 2),
                        if (bus == null)
                          Text(
                            'Sin buses en vivo en esta ruta',
                            style: AppTextStyles.pie
                                .copyWith(color: AppColors.textSecondary),
                          )
                        else if (llegada != null)
                          Wrap(
                            spacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                llegada,
                                style: AppTextStyles.pie
                                    .copyWith(color: AppColors.textBody),
                              ),
                              if (rango!.simulado) const _Simulacion(),
                            ],
                          ),
                      ],
                    ),
                  ),
                  if (cifra != null) ...[
                    const SizedBox(width: AppSpacing.md),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text.rich(
                          TextSpan(children: [
                            TextSpan(text: cifra.$1),
                            TextSpan(
                              text: ' ${cifra.$2.trim()}',
                              style: AppTextStyles.etiqueta
                                  .copyWith(color: AppColors.textPrimary),
                            ),
                          ]),
                          style: AppTextStyles.titulo.copyWith(
                            color: AppColors.textPrimary,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        Text(
                          'viene el bus',
                          style: AppTextStyles.pie
                              .copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// «Ruta 72» o «Ruta 72 y luego la 17»: el nombre corto de cada bus.
  static String _resumen(Viaje viaje, Map<String, String> nombres) {
    final codigos = [
      for (final t in viaje.enBus) codigoDeRuta(t.ruta, nombres[t.ruta]),
    ];
    return codigos.length == 1
        ? 'Ruta ${codigos.single}'
        : 'Ruta ${codigos.first} y luego la ${codigos.skip(1).join(' y la ')}';
  }
}

/// El código de la ficha: «72» de «72 Las Malvinas», y si el nombre no
/// trae código, su primera palabra; sin nombre, el id.
String codigoDeRuta(String id, String? nombre) {
  if (nombre == null || nombre.trim().isEmpty) return id;
  return routeCode(nombre)?.code ?? nombre.trim().split(RegExp(r'\s+')).first;
}

class _TiraDeTramos extends StatelessWidget {
  const _TiraDeTramos({required this.viaje, required this.nombres});

  final Viaje viaje;
  final Map<String, String> nombres;

  @override
  Widget build(BuildContext context) {
    final piezas = <Widget?>[
      for (final t in viaje.tramos)
        switch (t) {
          TramoAPie(:final metros) when metros > 0 => const Icon(
              Icons.directions_walk_rounded,
              size: 20,
              color: AppColors.textSecondary,
              semanticLabel: 'A pie',
            ),
          TramoEnBus(:final ruta, :final empresa) => FichaRuta(
              codigoDeRuta(ruta, nombres[ruta]),
              color: colorFicha(companyId: empresa.isEmpty ? null : empresa),
              lado: 28,
            ),
          _ => null,
        },
    ].nonNulls.toList();
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 4,
      runSpacing: 4,
      children: [
        for (var i = 0; i < piezas.length; i++) ...[
          if (i > 0)
            const Icon(Icons.chevron_right_rounded,
                size: 16, color: AppColors.textDisabled),
          piezas[i],
        ],
      ],
    );
  }
}

/// La etiqueta de lo que todavía es de ejemplo: el ritmo de la flota
/// simulada (D24) no es el de buses de verdad.
class _Simulacion extends StatelessWidget {
  const _Simulacion();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(AppRadius.xs),
        ),
        child: Text(
          'Simulación',
          style: AppTextStyles.pie.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
}
