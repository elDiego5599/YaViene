import 'package:flutter/material.dart';
import 'package:ya_viene_core/shared/widgets/indicador_carga.dart';
import 'package:ya_viene_core/ya_viene_core.dart' show AppMotion;

import '../theme/app_theme.dart';

/// De qué va la ventana. Decide el color del cuadro de icono y del botón
/// lleno; el resto de la ventana es igual para las tres.
enum VentanaTono {
  /// Crear, editar, contar algo. Icono en el azul de la consola y botón en
  /// el verde de INGRESAR, GUARDAR y AGREGAR: el verde es «adelante» en
  /// todo el panel.
  normal(AppColors.navy, AppColors.online),

  /// Se lleva algo que no vuelve —un bus, una ruta—. Rojo en el icono y en
  /// el botón, que es lo que ya pintaban las confirmaciones de borrado.
  peligro(AppColors.danger, AppColors.danger);

  const VentanaTono(this.icono, this.boton);

  final Color icono;
  final Color boton;
}

class VentanaAccion {
  const VentanaAccion(this.texto, this.alPulsar, {this.cargando = false});

  final String texto;

  /// Nulo apaga el botón (mientras se guarda, por ejemplo).
  final VoidCallback? alPulsar;

  /// El botón muestra la rueda en vez del texto, sin cambiar de ancho.
  final bool cargando;
}

/// La ventana del panel: todo lo que el panel pregunta o cuenta encima del
/// tablero —sesión vencida, agregar o editar un bus, el catálogo de rutas,
/// confirmar un borrado—.
///
/// Antes era el `AlertDialog` de fábrica con el tema encima: esquinas de
/// Material, sombra negra, un velo gris neutro y los botones como caían. La
/// de «Tu sesión expiró» ni siquiera llevaba eso; salía tal cual venía
/// (dueño, 2026-09-28). Esta es la ventana del pasajero (`Dialogo`) puesta
/// en escritorio: la misma bandeja clara de 6 alrededor, el mismo núcleo
/// blanco con su filo y el mismo velo azul noche. Lo que cambia es la
/// lectura: en el teléfono todo va centrado; aquí el icono va al lado del
/// título y los botones a la derecha, que es donde un programa de escritorio
/// los tiene y donde el operador los busca.
class Ventana extends StatelessWidget {
  const Ventana({
    super.key,
    required this.icono,
    required this.titulo,
    this.mensaje,
    this.contenido,
    this.principal,
    this.secundaria,
    this.tono = VentanaTono.normal,
    this.ancho = 440,
  });

  final IconData icono;
  final String titulo;

  /// El texto de la ventana, cuando es una pregunta o un aviso.
  final String? mensaje;

  /// Lo que va debajo del mensaje, cuando es un formulario.
  final Widget? contenido;

  /// El botón lleno. Sin él la ventana solo tiene la salida.
  final VentanaAccion? principal;

  /// La salida sin cambios (Cancelar, Cerrar). Botón de texto, a la
  /// izquierda del lleno.
  final VentanaAccion? secundaria;

  final VentanaTono tono;

  /// Ancho del núcleo. 440 deja una pregunta en tres líneas a 13,5 pt y un
  /// campo con su botón al lado sin apretarse; el catálogo de rutas pide
  /// algo más para que el nombre no se corte junto al contador y los dos
  /// lápices.
  final double ancho;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        // 24 de aire como mínimo contra el borde de la ventana del sistema:
        // a 1200×700, la ventana más chica que admite el panel, ninguna
        // ventana toca el borde.
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          // + 12: la bandeja de 6 a cada lado va por fuera del ancho útil.
          constraints: BoxConstraints(maxWidth: ancho + 12),
          child: Semantics(
            // Lo que el `Dialog` de Material hacía por su cuenta: el lector
            // de pantalla anuncia la ventana por su título y no deja salir
            // al tablero de abajo mientras está abierta.
            scopesRoute: true,
            namesRoute: true,
            explicitChildNodes: true,
            label: titulo,
            // La bandeja del pasajero: un filo claro que separa la ventana
            // del velo sin una sombra negra.
            child: Container(
              key: const ValueKey('ventana'),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0x1AFFFFFF),
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(color: const Color(0x24FFFFFF)),
                boxShadow: AppColors.sombraFlotante,
              ),
              // `Material` y no un `Container`: los campos, los botones de
              // icono y sus salpicaduras necesitan uno encima, y el recorte
              // evita que lo que se desplaza pinte esquinas rectas.
              child: Material(
                color: AppColors.surface,
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  side: const BorderSide(color: AppColors.border),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Cabecera(icono: icono, titulo: titulo, tono: tono),
                      if (mensaje != null) ...[
                        const SizedBox(height: 14),
                        Text(
                          mensaje!,
                          style: AppType.ui(
                            fontSize: 13.5,
                            height: 1.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                      if (contenido != null) ...[
                        const SizedBox(height: 20),
                        contenido!,
                      ],
                      if (principal != null || secundaria != null) ...[
                        const SizedBox(height: 24),
                        _Botones(
                          principal: principal,
                          secundaria: secundaria,
                          tono: tono,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Cabecera extends StatelessWidget {
  const _Cabecera({
    required this.icono,
    required this.titulo,
    required this.tono,
  });

  final IconData icono;
  final String titulo;
  final VentanaTono tono;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // El cuadro de icono que ya llevaban «Rutas» y «Nuevo bus» (34, al
        // 8 %), crecido a 40 y al 12 % del pasajero: ahora es la marca de
        // todas las ventanas y a 34 se perdía junto al título de 18.
        ExcludeSemantics(
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: tono.icono.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(icono, size: 20, color: tono.icono),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              titulo,
              style: AppType.ui(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                height: 1.25,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Botones extends StatelessWidget {
  const _Botones({
    required this.principal,
    required this.secundaria,
    required this.tono,
  });

  final VentanaAccion? principal;
  final VentanaAccion? secundaria;
  final VentanaTono tono;

  @override
  Widget build(BuildContext context) {
    // 44 de alto: el blanco de puntero cómodo en escritorio, cuatro menos
    // que los 48 del teléfono, que se piensan para el dedo.
    const alto = 44.0;
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (secundaria != null)
          SizedBox(
            height: alto,
            child: TextButton(
              onPressed: secundaria!.alPulsar,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                textStyle: AppType.ui(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: Text(secundaria!.texto),
            ),
          ),
        if (principal != null) ...[
          if (secundaria != null) const SizedBox(width: 8),
          SizedBox(
            height: alto,
            child: FilledButton(
              onPressed: principal!.cargando ? null : principal!.alPulsar,
              style: FilledButton.styleFrom(
                backgroundColor: tono.boton,
                foregroundColor: Colors.white,
                // Apagado mientras guarda: el mismo color al 55 %, no el
                // gris de fábrica, para que no parezca otro botón.
                disabledBackgroundColor: tono.boton.withValues(alpha: 0.55),
                disabledForegroundColor: Colors.white,
                // 112 de ancho mínimo: AGREGAR y su rueda de carga miden
                // lo mismo y el botón no salta al pulsarlo.
                minimumSize: const Size(112, alto),
                padding: const EdgeInsets.symmetric(horizontal: 22),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                textStyle: AppType.ui(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
              child: principal!.cargando
                  ? const IndicadorCarga(size: 18, color: Colors.white)
                  : Text(principal!.texto),
            ),
          ),
        ],
      ],
    );
  }
}

/// Abre una [Ventana] sobre el velo del panel.
///
/// El velo es el del pasajero —el azul noche del sistema al 62 %— y no el
/// negro al 54 de Material, que sobre el mapa claro ensuciaba los colores.
/// La ventana entra creciendo desde el 96 % mientras aparece: dos puntos
/// menos que en el teléfono, porque en una pantalla de escritorio la
/// ventana es más grande y el mismo 94 se leía como un salto.
///
/// [cerrable] en falso deja la ventana puesta hasta que se pulse su botón:
/// ni el clic fuera ni Esc la quitan. Es para la sesión vencida, que no
/// tiene otra salida que volver a entrar.
Future<T?> mostrarVentana<T>(
  BuildContext context,
  WidgetBuilder builder, {
  bool cerrable = true,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: cerrable,
    barrierLabel: 'Cerrar',
    barrierColor: AppColors.navyRaised.withValues(alpha: 0.62),
    transitionDuration: AppMotion.duracion(context, AppMotion.normal),
    pageBuilder: (dialogContext, _, _) => SafeArea(
      child: PopScope(canPop: cerrable, child: builder(dialogContext)),
    ),
    transitionBuilder: (context, animation, _, child) {
      final entrada = CurvedAnimation(
        parent: animation,
        curve: AppMotion.curvaEntrada,
        reverseCurve: AppMotion.curvaSalida,
      );
      return FadeTransition(
        opacity: entrada,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1).animate(entrada),
          child: child,
        ),
      );
    },
  );
}

/// Pregunta antes de borrar. Devuelve `true` solo si se pulsa el botón
/// rojo; Cancelar, Esc o el clic fuera dan `false`.
Future<bool> confirmarBorrado(
  BuildContext context, {
  required String titulo,
  required String mensaje,
}) async {
  final confirmado = await mostrarVentana<bool>(
    context,
    (dialogContext) => Ventana(
      icono: Icons.delete_outline_rounded,
      titulo: titulo,
      mensaje: mensaje,
      tono: VentanaTono.peligro,
      secundaria: VentanaAccion(
        'Cancelar',
        () => Navigator.of(dialogContext).pop(false),
      ),
      principal: VentanaAccion(
        'ELIMINAR',
        () => Navigator.of(dialogContext).pop(true),
      ),
    ),
  );
  return confirmado ?? false;
}

/// El aviso corto de abajo: «no se pudo eliminar el bus», «no se pudo abrir
/// WhatsApp». Era el `SnackBar` de fábrica, una barra roja o gris de lado a
/// lado de la ventana. Ahora es una tarjeta de la familia de la [Ventana]:
/// blanca, con su filo, su sombra y su cuadro de icono en el [tono]: rojo
/// para lo que falló, el verde de «En línea» para lo que salió bien.
class AvisoPanel extends StatelessWidget {
  const AvisoPanel({
    super.key,
    required this.mensaje,
    required this.icono,
    this.tono = AppColors.danger,
  });

  final String mensaje;
  final IconData icono;
  final Color tono;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('aviso_panel'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.sombraFlotante,
      ),
      child: Row(
        children: [
          // El cuadro de la cabecera de la ventana a 34: aquí va junto a una
          // línea de 13,5 y no junto a un título de 18.
          ExcludeSemantics(
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: tono.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(icono, size: 18, color: tono),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              mensaje,
              style: AppType.ui(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                height: 1.4,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Cuánto se queda un aviso: la misma cuenta que el pasajero
/// (`duracionDeAviso`). 60 ms por letra es una lectura tranquila, los 2 s de
/// base son lo que tarda el ojo en llegar abajo, el suelo de 4 s es el de
/// Material y el techo de 10 s evita que un aviso largo tape la lista.
Duration duracionDeAvisoPanel(String mensaje) =>
    Duration(milliseconds: (2000 + mensaje.length * 60).clamp(4000, 10000));

/// Muestra un [AvisoPanel] abajo en el centro. Quita el que hubiera: dos
/// fallos seguidos cuentan el último, no hacen cola.
void mostrarAvisoPanel(
  BuildContext context,
  String mensaje, {
  IconData icono = Icons.error_outline_rounded,
  Color tono = AppColors.danger,
}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        // El `SnackBar` solo presta la cola, la voz del lector de pantalla
        // y el gesto de apartarlo; lo que se ve es la tarjeta.
        backgroundColor: Colors.transparent,
        elevation: 0,
        padding: EdgeInsets.zero,
        behavior: SnackBarBehavior.floating,
        // 440: el ancho de la ventana. De lado a lado de una pantalla de
        // 1600 una línea de aviso quedaba perdida en la barra.
        width: 440,
        duration: duracionDeAvisoPanel(mensaje),
        content: AvisoPanel(mensaje: mensaje, icono: icono, tono: tono),
      ),
    );
}
