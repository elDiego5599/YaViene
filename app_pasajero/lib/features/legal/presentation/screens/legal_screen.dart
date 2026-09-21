import 'package:flutter/material.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

import '../../legal_docs.dart';

/// Un documento legal, leído dentro de la app.
///
/// Misma superficie y misma barra que Avisos: es una pantalla más de la
/// app, no una ventana de navegador metida con calzador. El texto se pinta
/// entero en una columna —no en una lista perezosa— porque es corto y
/// porque así se puede buscar en él con el lector de pantalla sin que los
/// trozos de abajo aparezcan solo al desplazarse.
class LegalScreen extends StatelessWidget {
  final LegalDoc doc;

  const LegalScreen({super.key, required this.doc});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.arena,
      appBar: AppBar(
        backgroundColor: AppColors.arena,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        // El mismo techo que en Avisos: la barra mide 56 y no se estira,
        // así que con el texto al triple el título se saldría por los dos
        // lados. Lo que sí crece es el documento.
        title: MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.3,
          child: Text(doc.title),
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 20,
            semanticLabel: 'Volver',
          ),
          tooltip: 'Volver',
          color: AppColors.textPrimary,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.xl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Actualizado el ${doc.updated}',
                style: AppTextStyles.etiqueta.copyWith(
                  // T6.6: `textDisabled` (#94A3B8) daba 2,41:1 sobre la
                  // arena y no pasa AA. Se usa `textSecondary`, el mismo
                  // token con el que el panel arregló sus rótulos en T6.1,
                  // no un gris nuevo.
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              for (final bloque in doc.blocks) _Bloque(bloque: bloque),
            ],
          ),
        ),
      ),
    );
  }
}

class _Bloque extends StatelessWidget {
  final LegalBlock bloque;

  const _Bloque({required this.bloque});

  @override
  Widget build(BuildContext context) {
    switch (bloque.kind) {
      case LegalBlockKind.heading:
        return Padding(
          // Más aire arriba que abajo: el titular pertenece a lo que viene
          // después, no a lo que acaba de terminar.
          padding: const EdgeInsets.only(top: 26, bottom: 10),
          child: Text(bloque.text, style: AppTextStyles.subtitulo),
        );
      case LegalBlockKind.paragraph:
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            bloque.text,
            style: AppTextStyles.cuerpo.copyWith(color: AppColors.textBody),
          ),
        );
      case LegalBlockKind.bullet:
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // El punto no se dice en voz alta: leído, «punto medio» antes
              // de cada viñeta es ruido. Lo que ordena la lista para quien
              // no la ve es el propio texto.
              ExcludeSemantics(
                child: Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: Text(
                    '·',
                    style: AppTextStyles.cuerpo.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  bloque.text,
                  style:
                      AppTextStyles.cuerpo.copyWith(color: AppColors.textBody),
                ),
              ),
            ],
          ),
        );
    }
  }
}
