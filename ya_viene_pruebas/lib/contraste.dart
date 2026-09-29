// La guía de contraste de Flutter, midiendo a más resolución.
//
// `textContrastGuideline` fotografía la pantalla a un píxel por punto y, por
// cada texto, se queda con el color claro y el color oscuro más frecuentes
// dentro de su caja. A un píxel por punto, un trazo de letra de 9,5 a 15
// puntos casi nunca cubre un píxel entero: la mayoría de los píxeles de la
// letra son borde suavizado, mezclas del color del texto con el fondo. Cuál
// de esas mezclas sale más veces depende de quién dibuja la letra, y eso
// cambia con el sistema: en el Mac las fuentes cargadas las rasteriza
// CoreText y en Linux FreeType. En Linux, «CONTROL DE FLOTA» (#5E6B82 sobre
// blanco, 5,4:1) deja 17 píxeles del color de verdad contra decenas de
// mezclas, y la guía mide #858EA0: 3,29:1. La misma pantalla pasa en el Mac
// y falla en Linux sin que el color haya cambiado.
//
// Esta guía hace lo mismo que la de Flutter —mismo recorrido de la
// semántica, misma partición en claros y oscuros, mismo umbral (4,5:1 o
// 3:1 para texto grande) y misma tolerancia— pero fotografía a [escala]
// píxeles por punto. Con tres, el trazo ya tiene píxeles enteros de sobra y
// el color oscuro más frecuente es el del texto en los dos sistemas: se mide
// el color que el usuario ve, que es lo que pide la WCAG, y no el suavizado
// de un rasterizador. Lo que sí tapa o aclara el texto (una capa encima, una
// opacidad) se sigue viendo, porque se sigue midiendo lo pintado.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// [textContrastGuideline] con la foto a tres píxeles por punto.
const AccessibilityGuideline guiaContraste = GuiaContraste();

/// [MinimumTextContrastGuideline] fotografiando a [escala] píxeles por punto.
// Flutter marca la guía «solo para pruebas», y el analizador solo reconoce
// como prueba lo que está en test/. Este paquete entero es de pruebas: las
// apps lo traen únicamente como dev_dependency.
// ignore: invalid_use_of_visible_for_testing_member
class GuiaContraste extends MinimumTextContrastGuideline {
  /// Crea la guía; [escala] es cuántos píxeles de la foto van por punto.
  const GuiaContraste({this.escala = 3});

  /// Píxeles de la foto por punto lógico. La guía de Flutter usa 1.
  final double escala;

  /// La de Flutter (privada allí): pasa lo que se queda a una centésima.
  static const double _tolerancia = -0.01;

  @override
  Future<Evaluation> evaluate(WidgetTester tester) async {
    var resultado = const Evaluation.pass();
    for (final vista in tester.binding.renderViews) {
      final capa = vista.debugLayer! as OffsetLayer;
      final raiz = vista.owner!.semanticsOwner!.rootSemanticsNode!;
      final foto = await tester.binding.runAsync<_Foto>(() async {
        // La capa raíz ya viene escalada a píxeles físicos: dividir por el
        // devicePixelRatio la deja en puntos, y multiplicar por la escala
        // la agranda lo pedido.
        final imagen = await capa.toImage(
          vista.paintBounds,
          pixelRatio: escala / vista.flutterView.devicePixelRatio,
        );
        final datos = await imagen.toByteData();
        final foto = _Foto(datos!, imagen.width, imagen.height);
        imagen.dispose();
        return foto;
      });
      resultado += await _evaluarNodo(raiz, tester, foto!, vista);
    }
    return resultado;
  }

  Future<Evaluation> _evaluarNodo(
    SemanticsNode nodo,
    WidgetTester tester,
    _Foto foto,
    RenderView vista,
  ) async {
    var resultado = const Evaluation.pass();
    final flags = nodo.flagsCollection;
    if (nodo.isInvisible ||
        nodo.isMergedIntoParent ||
        flags.isHidden ||
        flags.isEnabled == ui.Tristate.isFalse) {
      return resultado;
    }
    final datos = nodo.getSemanticsData();
    final hijos = <SemanticsNode>[];
    nodo.visitChildren((hijo) {
      hijos.add(hijo);
      return true;
    });
    for (final hijo in hijos) {
      resultado += await _evaluarNodo(hijo, tester, foto, vista);
    }
    if (shouldSkipNode(datos)) return resultado;
    final texto = datos.label.isEmpty ? datos.value : datos.label;
    for (final elemento in find.text(texto).hitTestable().evaluate()) {
      resultado += _evaluarElemento(nodo, elemento, foto, vista);
    }
    return resultado;
  }

  Evaluation _evaluarElemento(
    SemanticsNode nodo,
    Element elemento,
    _Foto foto,
    RenderView vista,
  ) {
    final caja = elemento.renderObject;
    if (caja is! RenderBox) {
      throw StateError('Unexpected renderObject type: $caja');
    }
    final global = caja.getTransformTo(null);
    final pintado = MatrixUtils.transformRect(
      global,
      caja.paintBounds.inflate(4.0),
    );

    // El nodo semántico trae la transformación de la vista raíz y
    // `getTransformTo(null)` no: se le suma para compararlos.
    final transformRaiz = Matrix4.identity();
    vista.applyPaintTransform(vista.child!, transformRaiz);
    transformRaiz.multiply(global);
    final enPantalla =
        MatrixUtils.transformRect(transformRaiz, caja.paintBounds);
    var limitesNodo = nodo.rect;
    for (SemanticsNode? n = nodo; n != null; n = n.parent) {
      final t = n.transform;
      if (t != null) limitesNodo = MatrixUtils.transformRect(t, limitesNodo);
    }
    final cruce = limitesNodo.intersect(enPantalla);
    // Este elemento no es el del nodo: otro texto igual en otro sitio.
    if (cruce.width <= 0 || cruce.height <= 0) {
      return const Evaluation.pass();
    }

    final widget = elemento.widget;
    final porDefecto = DefaultTextStyle.of(elemento).style;
    final TextStyle estilo;
    if (widget is Text) {
      final propio = widget.style;
      estilo = propio == null || propio.inherit
          ? porDefecto.merge(propio)
          : propio;
    } else if (widget is EditableText) {
      estilo = widget.style;
    } else {
      throw StateError('Unexpected widget type: ${widget.runtimeType}');
    }
    final negrita = estilo.fontWeight == FontWeight.bold;

    if (isNodeOffScreen(pintado, vista.flutterView)) {
      return const Evaluation.pass();
    }

    final histograma = foto.colores(pintado, escala);
    if (histograma.isEmpty) return const Evaluation.pass();

    final (:claro, :oscuro) = _clarosYOscuros(histograma);
    final contraste =
        (claro.computeLuminance() + 0.05) / (oscuro.computeLuminance() + 0.05);
    final objetivo = targetContrastRatio(estilo.fontSize, bold: negrita);
    if (contraste - objetivo >= _tolerancia) return const Evaluation.pass();
    return Evaluation.fail(
      '$nodo:\n'
      'Expected contrast ratio of at least $objetivo '
      'but found ${contraste.toStringAsFixed(2)} '
      'for a font size of ${estilo.fontSize} (sampled at ${escala}x).\n'
      'The computed colors was:\n'
      'light - $claro, dark - $oscuro\n'
      'See also: '
      'https://www.w3.org/TR/UNDERSTANDING-WCAG20/visual-audio-contrast-contrast.html',
    );
  }
}

/// El color claro y el oscuro más frecuentes, como los parte Flutter: por
/// encima o por debajo de la luminosidad HSL media de toda la caja.
({Color claro, Color oscuro}) _clarosYOscuros(Map<Color, int> histograma) {
  var suma = 0.0;
  var cuenta = 0;
  histograma.forEach((color, veces) {
    suma += HSLColor.fromColor(color).lightness * veces;
    cuenta += veces;
  });
  final media = suma / cuenta;
  MapEntry<Color, int>? claro;
  MapEntry<Color, int>? oscuro;
  for (final entrada in histograma.entries) {
    if (HSLColor.fromColor(entrada.key).lightness <= media) {
      if (entrada.value > (oscuro?.value ?? 0)) oscuro = entrada;
    } else if (entrada.value > (claro?.value ?? 0)) {
      claro = entrada;
    }
  }
  // Si solo hay un color, es a la vez el claro y el oscuro.
  return (
    claro: (claro ?? oscuro)!.key,
    oscuro: (oscuro ?? claro)!.key,
  );
}

/// Los píxeles RGBA de la pantalla fotografiada.
class _Foto {
  _Foto(this.datos, this.ancho, this.alto);

  final ByteData datos;
  final int ancho;
  final int alto;

  /// Cuántas veces sale cada color dentro de [rect], dado en puntos.
  Map<Color, int> colores(Rect rect, double escala) {
    final r = Rect.fromLTRB(
      rect.left * escala,
      rect.top * escala,
      rect.right * escala,
      rect.bottom * escala,
    ).intersect(
      Rect.fromLTWH(0, 0, ancho.toDouble(), alto.toDouble()),
    );
    final veces = <int, int>{};
    for (var x = r.left.floor(); x < r.right.ceil(); x++) {
      for (var y = r.top.floor(); y < r.bottom.ceil(); y++) {
        final rgba = datos.getUint32((y * ancho + x) * 4);
        veces.update(rgba, (n) => n + 1, ifAbsent: () => 1);
      }
    }
    return veces.map(
      (rgba, n) => MapEntry(Color((rgba << 24) | (rgba >> 8) & 0xFFFFFFFF), n),
    );
  }
}
