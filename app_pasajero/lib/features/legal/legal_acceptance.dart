import 'package:shared_preferences/shared_preferences.dart';

import 'legal_docs.dart';

/// El sí del pasajero a la privacidad y a los términos.
///
/// Sin cuenta no hay servidor que recuerde quién aceptó qué (D3), así que
/// el sí vive en el teléfono. Lo que se guarda no es un booleano sino la
/// versión del texto que se aceptó: con un sí a secas, el día que los
/// documentos cambien nadie se enteraría, y estaríamos enseñando un texto
/// que el usuario nunca vio como si lo hubiera aceptado.
const String kLegalAcceptedKey = 'legal_accepted_version';

Future<bool> isLegalAccepted() async {
  final prefs = await SharedPreferences.getInstance();
  final aceptada = prefs.getInt(kLegalAcceptedKey);
  return aceptada != null && aceptada >= kLegalVersion;
}

Future<void> acceptLegal() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setInt(kLegalAcceptedKey, kLegalVersion);
}
