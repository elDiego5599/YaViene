// El panel de punta a punta: la app de escritorio compilada, en su ventana,
// contra un backend de verdad. Las pruebas de `test/` montan pantallas
// sueltas con la red falsa; esta es la única que pasa por el login real, el
// token, el socket de flota y la API de buses de una vez.
//
// No se corre con `flutter test` a secas: necesita el backend de usar y
// tirar que levanta `tool/e2e-panel.sh` (base, puertos y cuenta propios; el
// backend vivo no se toca). Sin sus defines se salta.
//
// El llavero tampoco se toca: el panel guarda la sesión y la contraseña
// recordada en el llavero clásico del Mac, y una corrida de esto en el Mac
// del dueño le borraría la sesión del panel de verdad (el logout la borra) o
// le pediría la clave del llavero. El almacén va en memoria.
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:window_manager/window_manager.dart';
import 'package:ya_viene_control/config.dart';
import 'package:ya_viene_control/core/widgets/ventana_minima.dart';
import 'package:ya_viene_control/features/auth/presentation/screens/login_screen.dart';
import 'package:ya_viene_control/features/fleet/presentation/widgets/fleet_list_tile.dart';
import 'package:ya_viene_control/main.dart';
import 'package:ya_viene_core/core/providers/app_providers.dart'
    show BackendUrl, backendUrlProvider;

const _usuario = String.fromEnvironment('E2E_USUARIO');
const _clave = String.fromEnvironment('E2E_CLAVE');

/// Bombea cuadros hasta que [hecho] se cumpla. `pumpAndSettle` no sirve
/// aquí: el reloj de la cabecera cambia cada segundo y las teselas del mapa
/// siguen llegando, así que la pantalla nunca «se asienta».
Future<void> _esperar(
  WidgetTester tester,
  bool Function() hecho, {
  required String porQue,
  Duration limite = const Duration(seconds: 20),
}) async {
  final fin = DateTime.now().add(limite);
  while (!hecho()) {
    if (DateTime.now().isAfter(fin)) {
      // Lo que había en pantalla, para no tener que adivinar dónde se quedó.
      final textos = find
          .byType(Text)
          .evaluate()
          .map((e) => (e.widget as Text).data)
          .whereType<String>()
          .toSet();
      fail('Tras $limite: $porQue. En pantalla: $textos');
    }
    await tester.pump(const Duration(milliseconds: 100));
  }
}

bool _hay(Finder f) => f.evaluate().isNotEmpty;

/// Toca [f] cuando ya está quieto dentro de la ventana. Las pantallas y las
/// ventanas entran deslizándose: tocar en medio cae donde el botón todavía
/// no está (lo que le pasaba a «Salir» al volver a entrar).
Future<void> _tocar(
  WidgetTester tester,
  Finder f, {
  required String que,
}) async {
  Offset? antes;
  final pantalla =
      Offset.zero & tester.view.physicalSize / tester.view.devicePixelRatio;
  await _esperar(tester, () {
    if (!_hay(f)) return false;
    final centro = tester.getCenter(f.first, warnIfMissed: false);
    final quieto = centro == antes && pantalla.contains(centro);
    antes = centro;
    return quieto;
  }, porQue: '$que no quedó quieto en pantalla');
  await tester.tap(f.first);
  await tester.pump();
}

/// Las ventanas propias del panel (`core/widgets/ventana.dart`).
final _ventana = find.byKey(const ValueKey('ventana'));

Future<void> _entrar(WidgetTester tester, String clave) async {
  // Dentro de la entrada: mientras la transición de «Salir» termina, el
  // tablero sigue montado y su buscador también es un TextField.
  final campos = find.descendant(
    of: find.byType(LoginScreen),
    matching: find.byType(TextField),
  );
  await tester.enterText(campos.at(0), _usuario);
  await tester.enterText(campos.at(1), clave);
  await _tocar(tester, find.text('INGRESAR'), que: 'INGRESAR');
}

Future<void> _salir(WidgetTester tester) async {
  await _tocar(tester, find.text('Salir'), que: '«Salir»');
  await _esperar(
    tester,
    () => _hay(find.text('INGRESAR')) && !_hay(find.text('Salir')),
    porQue: '«Salir» no volvió a la entrada',
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // Un toque que no cae en su botón es un error, no un aviso en el log.
  WidgetController.hitTestWarningShouldBeFatal = true;

  testWidgets(
    'entra, ve su flota, agrega y borra un bus, y sale',
    skip: _usuario.isEmpty || _clave.isEmpty,
    (tester) async {
      FlutterSecureStorage.setMockInitialValues({});

      // La ventana como la abre `main.dart`, sin maximizar: 1600×900 cabe
      // en cualquier pantalla de desarrollo y queda por encima del mínimo.
      if (Platform.isMacOS || Platform.isWindows) {
        await windowManager.ensureInitialized();
        await windowManager.setMinimumSize(ventanaMinima);
        await windowManager.setSize(const Size(1600, 900));
      }

      // Sin el respaldo de `main.dart`: si el backend temporal no
      // contestara, la app se iría a Fly y la prueba pasaría o fallaría
      // contra datos ajenos.
      final container = ProviderContainer(
        overrides: [
          backendUrlProvider.overrideWith(
            () => BackendUrl.fija(AppConfig.backendUrl),
          ),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const YaVieneControlApp(),
        ),
      );
      await _esperar(
        tester,
        () => _hay(find.text('INGRESAR')),
        porQue: 'no apareció la entrada',
      );
      expect(
        tester.view.physicalSize.width / tester.view.devicePixelRatio,
        greaterThanOrEqualTo(ventanaMinima.width),
      );

      // 1) Con la contraseña mal, el backend dice que no y se queda aquí.
      await _entrar(tester, '${_clave}x');
      await _esperar(
        tester,
        () => _hay(find.text('Usuario o contraseña incorrectos.')),
        porQue: 'la contraseña errada no dio su error',
      );
      expect(find.text('Salir'), findsNothing);

      // 2) Con la buena, el panel y el bus que sembró el script.
      await _entrar(tester, _clave);
      await _esperar(
        tester,
        () => _hay(find.text('ABC123')),
        porQue: 'el panel no mostró el bus sembrado',
      );

      // 3) Agregar un bus: la ventana, la placa, AGREGAR, y en la lista.
      await _tocar(tester, find.text('Agregar bus'), que: '«Agregar bus»');
      await _esperar(
        tester,
        () => _hay(find.text('Nuevo bus')),
        porQue: 'no abrió «Nuevo bus»',
      );
      await tester.enterText(
        find.descendant(of: _ventana, matching: find.byType(TextField)),
        'XYZ789',
      );
      await _tocar(tester, find.text('AGREGAR'), que: 'AGREGAR');
      await _esperar(
        tester,
        () => !_hay(_ventana) && _hay(find.text('XYZ789')),
        porQue: 'el bus nuevo no llegó a la lista',
      );

      // 4) Borrarlo desde su ficha, con la confirmación.
      // Por su fila de la lista: la placa también va en el rótulo del bus
      // en el mapa.
      await _tocar(
        tester,
        find.ancestor(
          of: find.text('XYZ789'),
          matching: find.byType(FleetListTile),
        ),
        que: 'la fila de XYZ789',
      );
      await _esperar(
        tester,
        () => _hay(find.byTooltip('Eliminar bus de la flota')),
        porQue: 'no abrió la ficha del bus',
      );
      await _tocar(
        tester,
        find.byTooltip('Eliminar bus de la flota'),
        que: 'el botón de borrar',
      );
      await _esperar(
        tester,
        () => _hay(find.text('ELIMINAR')),
        porQue: 'no pidió confirmar el borrado',
      );
      await _tocar(tester, find.text('ELIMINAR'), que: 'ELIMINAR');
      await _esperar(
        tester,
        // Y la confirmación cerrada del todo: mientras se desvanece, su
        // fondo se traga el toque de «Salir».
        () => !_hay(find.text('XYZ789')) && !_hay(_ventana),
        porQue: 'el bus borrado siguió en la lista',
      );

      // 5) Salir y volver a entrar: lo que se ve sale del servidor, no de
      //    lo que el panel recordaba. Si el borrado no hubiera llegado al
      //    backend, XYZ789 volvería aquí.
      await _salir(tester);
      await _entrar(tester, _clave);
      await _esperar(
        tester,
        () => _hay(find.text('ABC123')),
        porQue: 'tras volver a entrar no llegó la flota',
      );
      expect(find.text('XYZ789'), findsNothing);
      await _salir(tester);
    },
  );
}
