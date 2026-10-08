// «Recordar contraseña» en la entrada del panel (pedido del dueño,
// 2026-09-28).
//
// La casilla va apagada si no hay nada recordado; si lo hay, la pantalla
// abre con usuario y clave puestos y la casilla encendida, y INGRESAR le
// dice al login si recordar o no. Dónde y cómo se guarda lo fija
// auth_providers_test.dart. Los valores son de prueba.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ya_viene_control/core/theme/app_theme.dart';
import 'package:ya_viene_control/features/auth/data/auth_api.dart';
import 'package:ya_viene_control/features/auth/domain/auth_session.dart';
import 'package:ya_viene_control/features/auth/presentation/providers/auth_providers.dart';
import 'package:ya_viene_control/features/auth/presentation/screens/login_screen.dart';

class _FakeAuthApi extends AuthApi {
  _FakeAuthApi() : super(baseUrl: 'http://localhost:3000');

  final List<(String, String)> ingresos = [];

  @override
  Future<AuthSession> login(String username, String password) async {
    ingresos.add((username, password));
    return const AuthSession(
      token: 't-1',
      companyId: 'c-1',
      companyName: 'Empresa 1',
    );
  }
}

class _FakeSecureStorage extends FlutterSecureStorage {
  _FakeSecureStorage([Map<String, String>? inicial]) : valores = {...?inicial};

  final Map<String, String> valores;

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => valores[key];

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      valores.remove(key);
    } else {
      valores[key] = value;
    }
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => valores.remove(key);
}

Future<void> _montar(
  WidgetTester tester,
  _FakeAuthApi api,
  _FakeSecureStorage storage, {
  bool web = false,
}) async {
  await tester.binding.setSurfaceSize(const Size(1366, 768));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authProvider.overrideWith(
          (ref) => AuthNotifier(api: api, storage: storage, web: web),
        ),
      ],
      // Con su router: al entrar, la pantalla se va a /dashboard.
      child: MaterialApp.router(
        theme: AppTheme.light,
        routerConfig: GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) => LoginScreen(web: web),
            ),
            GoRoute(path: '/dashboard', builder: (_, _) => const Text('panel')),
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

String _texto(WidgetTester tester, int campo) =>
    tester.widget<TextField>(find.byType(TextField).at(campo)).controller!.text;

/// Si el campo de la clave está en puntos.
bool _oculta(WidgetTester tester) => tester
    .widget<EditableText>(
      find.descendant(
        of: find.byType(TextField).at(1),
        matching: find.byType(EditableText),
      ),
    )
    .obscureText;

bool _casilla(WidgetTester tester) =>
    tester.widget<Checkbox>(find.byType(Checkbox)).value!;

void main() {
  testWidgets('sin nada recordado, campos vacíos y la casilla apagada', (
    tester,
  ) async {
    await _montar(tester, _FakeAuthApi(), _FakeSecureStorage());

    expect(find.text('Recordar contraseña'), findsOneWidget);
    expect(_casilla(tester), isFalse);
    expect(_texto(tester, 0), isEmpty);
    expect(_texto(tester, 1), isEmpty);
  });

  testWidgets('con algo recordado, abre con usuario y clave puestos', (
    tester,
  ) async {
    await _montar(
      tester,
      _FakeAuthApi(),
      _FakeSecureStorage({
        'recordar_usuario': 'operador',
        'recordar_clave': 'clave-de-prueba',
      }),
    );

    expect(_texto(tester, 0), 'operador');
    expect(_texto(tester, 1), 'clave-de-prueba');
    expect(_casilla(tester), isTrue);
  });

  testWidgets('el rótulo también marca la casilla, e INGRESAR la respeta', (
    tester,
  ) async {
    final api = _FakeAuthApi();
    final storage = _FakeSecureStorage();
    await _montar(tester, api, storage);

    await tester.enterText(find.byType(TextField).at(0), 'operador');
    await tester.enterText(find.byType(TextField).at(1), 'clave-de-prueba');
    await tester.tap(find.text('Recordar contraseña'));
    await tester.pump();
    expect(_casilla(tester), isTrue);

    await tester.tap(find.text('INGRESAR'));
    await tester.pumpAndSettle();

    expect(find.text('panel'), findsOneWidget);
    expect(api.ingresos, [('operador', 'clave-de-prueba')]);
    expect(jsonDecode(storage.valores['recordar']!), {
      'usuario': 'operador',
      'clave': 'clave-de-prueba',
    });
  });

  // La clave recordada viaja del almacén al campo para que INGRESAR la
  // mande, pero el ojo no la enseña: en un equipo de oficina, después de
  // «Salir», cualquiera podía leer la clave de la flota con un clic
  // (auditoría 2026-09, H4). El ojo solo muestra lo tecleado aquí.
  testWidgets('el ojo no revela la clave recordada', (tester) async {
    final api = _FakeAuthApi();
    await _montar(
      tester,
      api,
      _FakeSecureStorage({
        'recordar_usuario': 'operador',
        'recordar_clave': 'clave-de-prueba',
      }),
    );

    await tester.tap(find.byType(IconButton));
    await tester.pump();
    expect(_oculta(tester), isTrue);
    expect(
      find.byTooltip('La contraseña recordada no se muestra'),
      findsOneWidget,
    );

    // Sin tocarla, INGRESAR entra con ella: «Recordar contraseña» sigue.
    await tester.tap(find.text('INGRESAR'));
    await tester.pumpAndSettle();
    expect(api.ingresos, [('operador', 'clave-de-prueba')]);
  });

  testWidgets('teclear sobre la clave recordada la reemplaza y el ojo muestra '
      'solo lo nuevo', (tester) async {
    await _montar(
      tester,
      _FakeAuthApi(),
      _FakeSecureStorage({
        'recordar_usuario': 'operador',
        'recordar_clave': 'clave-de-prueba',
      }),
    );
    final campo = find.byType(TextField).at(1);
    await tester.showKeyboard(campo);
    await tester.pump();

    // Una letra al final, como la escribe el teclado: el valor de antes con
    // el cursor al final, más la letra.
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: 'clave-de-pruebaX',
        selection: TextSelection.collapsed(offset: 16),
      ),
    );
    await tester.pump();
    expect(_texto(tester, 1), 'X');

    await tester.tap(find.byType(IconButton));
    await tester.pump();
    expect(_oculta(tester), isFalse);
    expect(find.byTooltip('Ocultar contraseña'), findsOneWidget);
  });

  testWidgets('borrar sobre la clave recordada la vacía entera', (
    tester,
  ) async {
    await _montar(
      tester,
      _FakeAuthApi(),
      _FakeSecureStorage({
        'recordar_usuario': 'operador',
        'recordar_clave': 'clave-de-prueba',
      }),
    );
    final campo = find.byType(TextField).at(1);
    await tester.showKeyboard(campo);
    await tester.pump();

    // Un toque en medio y retroceso: sin esta regla quedaba «clave-e-prueba»
    // y el ojo la mostraba casi entera.
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: 'clave-e-prueba',
        selection: TextSelection.collapsed(offset: 6),
      ),
    );
    await tester.pump();
    expect(_texto(tester, 1), isEmpty);
  });

  testWidgets('se oye como una casilla con su nombre', (tester) async {
    final semantica = tester.ensureSemantics();
    await _montar(tester, _FakeAuthApi(), _FakeSecureStorage());

    expect(
      tester.getSemantics(find.byType(Checkbox)),
      isSemantics(
        label: 'Recordar contraseña',
        hasCheckedState: true,
        isChecked: false,
        hasTapAction: true,
      ),
    );
    semantica.dispose();
  });

  // En el navegador el panel no guarda nada: la casilla no se ofrece y la
  // clave la recuerda, si se quiere, el gestor de contraseñas del navegador.
  // Para eso los campos dicen qué son y, al entrar, se le avisa que el
  // formulario terminó y puede ofrecer guardarla.
  group('en el navegador', () {
    testWidgets('no hay casilla de recordar', (tester) async {
      await _montar(tester, _FakeAuthApi(), _FakeSecureStorage(), web: true);

      expect(find.byType(Checkbox), findsNothing);
      expect(find.text('Recordar contraseña'), findsNothing);
    });

    testWidgets('usuario y clave van en un grupo de autocompletar', (
      tester,
    ) async {
      await _montar(tester, _FakeAuthApi(), _FakeSecureStorage(), web: true);

      final campos = find.descendant(
        of: find.byType(AutofillGroup),
        matching: find.byType(TextField),
      );
      expect(campos, findsNWidgets(2));
      expect(tester.widget<TextField>(campos.at(0)).autofillHints, [
        AutofillHints.username,
      ]);
      expect(tester.widget<TextField>(campos.at(1)).autofillHints, [
        AutofillHints.password,
      ]);
    });

    testWidgets('al entrar se cierra el autocompletar para que lo guarde', (
      tester,
    ) async {
      await _montar(tester, _FakeAuthApi(), _FakeSecureStorage(), web: true);
      final cierres = <Object?>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.textInput,
        (llamada) async {
          if (llamada.method == 'TextInput.finishAutofillContext') {
            cierres.add(llamada.arguments);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.textInput,
          null,
        ),
      );

      await tester.enterText(find.byType(TextField).at(0), 'operador');
      await tester.enterText(find.byType(TextField).at(1), 'clave-de-prueba');
      await tester.tap(find.text('INGRESAR'));
      await tester.pumpAndSettle();

      expect(find.text('panel'), findsOneWidget);
      expect(cierres, [true]);
    });
  });

  // En el escritorio el Llavero ya recuerda: el sistema no debe ofrecer
  // además guardar la clave de la flota por su cuenta.
  testWidgets('en el escritorio los campos no piden autocompletar', (
    tester,
  ) async {
    await _montar(tester, _FakeAuthApi(), _FakeSecureStorage());

    expect(find.byType(AutofillGroup), findsNothing);
    for (final campo in tester.widgetList<TextField>(find.byType(TextField))) {
      expect(campo.autofillHints, anyOf(isNull, isEmpty));
    }
  });
}
