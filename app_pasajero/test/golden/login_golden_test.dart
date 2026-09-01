import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_pasajero/core/providers/auth_provider.dart';
import 'package:ya_viene_pasajero/features/auth/presentation/screens/'
    'login_screen.dart';

import 'golden_harness.dart';

/// El inicio de sesión en sus tres pasos.
///
/// Doce estilos escritos a mano y ni una sola transición animada entre los
/// pasos: hoy los campos aparecen y desaparecen de golpe. La Fase 1 le pone
/// movimiento, y estas fotos son el "antes".
///
/// `AuthNotifier` no se puede heredar para esquivar Firebase: crea el
/// `FirebaseAuth.instance` en la declaración del campo, así que el
/// constructor del hijo ya lo habría tocado. Se implementa la interfaz y se
/// responde solo a lo que la pantalla pregunta.
class _AutenticacionFalsa implements AuthNotifier {
  _AutenticacionFalsa({required this.correoConocido});

  /// Decide a qué paso salta la pantalla tras "Continuar": a la contraseña
  /// si el correo ya existe, al perfil si es alguien nuevo.
  final bool correoConocido;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    switch (invocation.memberName) {
      case #state:
        return const AuthState();
      case #isEmailValid:
        final texto = invocation.positionalArguments.first as String;
        return texto.contains('@') && texto.contains('.');
      case #checkEmail:
        return Future<bool>.value(correoConocido);
      default:
        return null;
    }
  }
}

void main() {
  Future<void> montar(WidgetTester tester, {bool correoConocido = true}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(
            (ref) => _AutenticacionFalsa(correoConocido: correoConocido),
          ),
        ],
        child: marcoGoldenRuteado(const LoginScreen(), ruta: '/login'),
      ),
    );
    // El fondo (`LiveRouteBackdrop`) late para siempre: `pumpAndSettle` no
    // volvería. Un salto fijo desde el arranque deja la entrada terminada y
    // el bus del fondo siempre en el mismo punto.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
  }

  Future<void> escribirCorreoYSeguir(WidgetTester tester) async {
    await tester.enterText(
      find.byType(TextField).first,
      'sofia@yaviene.app',
    );
    await tester.pump();
    await tester.tap(find.text('Continuar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('inicio de sesión · paso del correo', (tester) async {
    fijarPantalla(tester);
    await montar(tester);
    await coincideConOro(tester, 'login_correo');
  });

  testWidgets('inicio de sesión · paso de la contraseña', (tester) async {
    fijarPantalla(tester);
    await montar(tester);
    await escribirCorreoYSeguir(tester);
    await coincideConOro(tester, 'login_contrasena');
  });

  testWidgets('inicio de sesión · paso del perfil', (tester) async {
    fijarPantalla(tester);
    await montar(tester, correoConocido: false);
    await escribirCorreoYSeguir(tester);
    await coincideConOro(tester, 'login_perfil');
  });

  // El paso del perfil al 130%: cuatro campos, dos botones y el héroe
  // encima, en la pantalla con menos aire de la app. Si algo se sale, se
  // sale aquí.
  testWidgets('inicio de sesión · perfil con texto al 130%', (tester) async {
    fijarPantalla(tester, escalaTexto: 1.3);
    await montar(tester, correoConocido: false);
    await escribirCorreoYSeguir(tester);
    await coincideConOro(tester, 'login_perfil_texto_grande');
  });
}
