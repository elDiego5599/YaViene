import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// Abre un enlace fuera de la app, en el navegador, como en el panel. Es un
/// provider para que las pruebas vean qué se abrió sin abrir nada.
final abrirEnlaceProvider = Provider<Future<bool> Function(Uri)>(
  (ref) => (uri) => launchUrl(uri, mode: LaunchMode.externalApplication),
);
