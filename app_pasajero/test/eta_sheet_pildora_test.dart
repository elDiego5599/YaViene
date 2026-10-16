import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import 'package:ya_viene_pasajero/core/widgets/pildora_navegacion.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/user_location_provider.dart';
import 'package:ya_viene_pasajero/features/map/presentation/widgets/eta_bottom_sheet.dart';

class _TestUserLocation extends UserLocationNotifier {
  void set(UserLocationState state) => this.state = state;
}

/// La hoja del mapa crece de la barra de abajo (dueño, 2026-10-16): no es
/// una tarjeta propia de borde a borde con la barra flotando encima, sino
/// la misma superficie, con sus cantos y su hueco, que sube desde ella.
void main() {
  Future<void> montar(WidgetTester tester, {double? barra}) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(overrides: [
      userLocationProvider.overrideWith((ref) => _TestUserLocation()),
    ]);
    addTearDown(container.dispose);
    const hoja = Stack(
      children: [
        Positioned(left: 0, right: 0, bottom: 0, child: EtaBottomSheet()),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(390, 844),
              viewPadding: EdgeInsets.only(top: 47, bottom: 34),
              padding: EdgeInsets.only(top: 47, bottom: 34),
            ),
            child: Scaffold(
              body: barra == null
                  ? hoja
                  : PildoraVisible(visible: barra, child: hoja),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    (container.read(userLocationProvider.notifier) as _TestUserLocation).set(
      const UserLocationState(
        mode: UserLocationMode.manual,
        lat: 10.99,
        lon: -74.8,
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder caja() => find
      .ancestor(
        of: find.byKey(const ValueKey('sheet-handle')),
        matching: find.byWidgetPredicate(
            (w) => w is DecoratedBox && w.decoration is ShapeDecoration),
      )
      .first;

  Rect tarjeta(WidgetTester tester) => tester.getRect(caja());

  testWidgets('va a lo ancho de la barra y se apoya donde ella',
      (tester) async {
    await montar(tester, barra: 1);

    final r = tarjeta(tester);
    // La barra: 20 por lado y 22 sobre el borde con la barra de inicio de
    // 34 (`PildoraNavegacion.hueco`).
    expect(r.left, 20);
    expect(r.right, 370);
    expect(r.bottom, 844 - 22);
  });

  testWidgets('lo de la hoja termina encima de la barra', (tester) async {
    await montar(tester, barra: 1);

    final contenido =
        tester.getRect(find.byKey(const ValueKey('sheet-pliegue')));
    expect(contenido.bottom,
        lessThanOrEqualTo(tarjeta(tester).bottom - PildoraNavegacion.alto));
  });

  testWidgets('sin barra a la vista no le guarda el sitio', (tester) async {
    await montar(tester, barra: 0);

    final contenido =
        tester.getRect(find.byKey(const ValueKey('sheet-pliegue')));
    expect(contenido.bottom,
        greaterThan(tarjeta(tester).bottom - PildoraNavegacion.alto));
    expect(tarjeta(tester).bottom, 844 - 22);
  });

  testWidgets('fuera de las pestañas, la misma tarjeta sin barra',
      (tester) async {
    await montar(tester);

    expect(tarjeta(tester).left, 20);
    expect(tarjeta(tester).bottom, 844 - 22);
  });

  testWidgets('la hoja es blanca como la barra', (tester) async {
    await montar(tester, barra: 1);

    // Fondos blancos y lo blanco de encima con sombra (dueño, 2026-10-16):
    // la hoja es del blanco de la barra de la que crece. La sombra de la
    // tarjeta del bus la mide `eta_sheet_placa_test`.
    expect(
        (tester.widget<DecoratedBox>(caja()).decoration as ShapeDecoration)
            .color,
        AppColors.surface);
  });

  testWidgets('la tarjeta redondea sus cuatro cantos como la barra',
      (tester) async {
    await montar(tester, barra: 1);

    final forma =
        (tester.widget<DecoratedBox>(caja()).decoration as ShapeDecoration)
            .shape as RoundedRectangleBorder;
    expect(
        forma.borderRadius, BorderRadius.circular(PildoraNavegacion.alto / 2));
  });
}
