import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import 'package:ya_viene_pasajero/core/widgets/sheet_top_border.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/map_tour_provider.dart';
import 'package:ya_viene_pasajero/features/map/presentation/widgets/route_selector_sheet.dart';

import 'guia_huecos_test.dart'
    show Telefono, telefonos, ponerTelefono, pintor, carta, contiene;
import 'helpers/fuentes.dart';

/// Las áreas iluminadas de los pasos del selector (empresa, ruta y «Ver
/// buses»), en la vista principal y en las listas, en tres teléfonos y con
/// la letra normal y grande (dueño, 2026-10-18).
///
/// En cada paso: la carta no pisa el hueco ni sale de la zona segura, lo
/// que se enseña está dentro, la cabecera de la lista (título y flecha de
/// volver) está fuera, y el hueco no lleva aire de más bajo la última fila.
void main() {
  setUpAll(cargarFuentes);

  const empresas = [
    Company(id: 'EMP-01', name: 'Sobusa'),
    Company(id: 'EMP-02', name: 'Coolitoral'),
  ];
  const rutas = [
    RouteInfo(id: 'R-106', name: 'B18 Ruta 106', companyId: 'EMP-01'),
    RouteInfo(id: 'R-107', name: 'C11 Ruta 107', companyId: 'EMP-01'),
    RouteInfo(id: 'R-108', name: 'C16 Ruta 108', companyId: 'EMP-01'),
  ];

  /// Un texto de la hoja, no el de la carta de la guía.
  Finder deLaHoja(String texto) => find.byWidgetPredicate((w) =>
      w is Text &&
      w.data == texto &&
      find
          .ancestor(
              of: find.byWidget(w),
              matching: find.byKey(const ValueKey('guide_card')))
          .evaluate()
          .isEmpty);

  /// La carta no tapa la cabecera de la hoja: va entera encima si cabe; si
  /// no, al menos no tapa el título de la vista.
  void cartaFueraDeLaHoja(
      WidgetTester tester, Telefono t, String titulo, String paso) {
    final c = carta(tester);
    final hoja = tester.getRect(find.ancestor(
        of: deLaHoja(titulo),
        matching: find.byWidgetPredicate(
            (w) => w is Material && w.shape is SheetTopBorder)));
    final cabe = c.height + 12 <= hoja.top - (t.arriba + 8);
    if (cabe) {
      expect(c.bottom, lessThanOrEqualTo(hoja.top - 12 + 0.5),
          reason: '$paso: la carta $c tapa la hoja ${hoja.top}');
    }
  }

  void enZonaSegura(WidgetTester tester, Telefono t, String paso) {
    final hueco = pintor(tester).hole;
    final c = carta(tester);
    expect(c.overlaps(hueco), isFalse,
        reason: '$paso: la carta $c pisa el hueco $hueco');
    expect(c.top, greaterThanOrEqualTo(t.arriba + 8 - 0.5),
        reason: '$paso: la carta se mete bajo la isla');
    expect(c.bottom,
        lessThanOrEqualTo(t.tam.height - (t.abajo - 16).clamp(12, 99) + 0.5),
        reason: '$paso: la carta baja hasta la barra de inicio');
    expect(hueco.height, greaterThanOrEqualTo(48), reason: paso);
  }

  /// La lista: sus filas dentro, la cabecera fuera, sin aire de más.
  void lista(
      WidgetTester tester, String titulo, List<String> filas, String paso) {
    final hueco = pintor(tester).hole;
    Rect fila(String texto) => tester.getRect(find
        .ancestor(of: find.text(texto), matching: find.byType(InkWell))
        .first);
    for (final f in filas) {
      expect(contiene(hueco, fila(f)), isTrue,
          reason: '$paso: «$f» ${fila(f)} queda fuera de $hueco');
    }
    expect(tester.getRect(deLaHoja(titulo)).overlaps(hueco), isFalse,
        reason: '$paso: el título queda iluminado');
    expect(tester.getRect(find.byTooltip('Volver')).overlaps(hueco), isFalse,
        reason: '$paso: la flecha de volver queda iluminada');
    final ultima = fila(filas.last);
    expect(hueco.bottom - ultima.bottom, lessThanOrEqualTo(12 + 0.5),
        reason: '$paso: el hueco lleva '
            '${(hueco.bottom - ultima.bottom).toStringAsFixed(1)} de aire '
            'bajo la última fila');
    final primera = fila(filas.first);
    expect(primera.top - hueco.top, lessThanOrEqualTo(16 + 0.5),
        reason: '$paso: aire de más encima de la primera fila');
  }

  for (final t in telefonos) {
    for (final letra in [1.0, 1.35]) {
      testWidgets('los huecos del selector en ${t.nombre} con letra ×$letra',
          (tester) async {
        await ponerTelefono(tester, t, letra);
        SharedPreferences.setMockInitialValues({});
        final guia = MapGuideNotifier();
        await guia.initialize(
          hasLocation: true,
          locationSettled: true,
          hasRoute: false,
          hasSelectedBus: false,
          hasActiveAlert: false,
        );
        await guia.empezar();
        await guia.moveTo(MapGuideStep.company);
        final container = ProviderContainer(overrides: [
          mapGuideProvider.overrideWith((ref) => guia),
          companiesProvider.overrideWith((ref) async => empresas),
          routesByCompanyProvider.overrideWith((ref, id) async => rutas),
        ]);
        addTearDown(container.dispose);
        container.listen(selectedCompanyProvider, (_, __) {});
        container.listen(selectedRouteProvider, (_, __) {});
        final empresaKey = GlobalKey();
        final rutaKey = GlobalKey();
        final verKey = GlobalKey();

        await tester.pumpWidget(UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => Center(
                  child: ElevatedButton(
                    onPressed: () => RouteSelectorSheet.show(
                      context,
                      sheet: RouteSelectorSheet(
                        companyGuideKey: empresaKey,
                        companyChoiceGuideKey: GlobalKey(),
                        routeGuideKey: rutaKey,
                        routeChoiceGuideKey: GlobalKey(),
                        launchBusesGuideKey: verKey,
                      ),
                    ),
                    child: const Text('abrir'),
                  ),
                ),
              ),
            ),
          ),
        ));
        await tester.tap(find.text('abrir'));
        await tester.pumpAndSettle();

        // Empresa, en la principal: su fila entera.
        enZonaSegura(tester, t, 'empresa');
        cartaFueraDeLaHoja(tester, t, 'Elige tu ruta', 'empresa');
        expect(
            contiene(
                pintor(tester).hole, tester.getRect(find.byKey(empresaKey))),
            isTrue,
            reason: 'empresa: la fila queda fuera');

        await tester.tap(find.byKey(empresaKey));
        await tester.pumpAndSettle();
        enZonaSegura(tester, t, 'lista de empresas');
        cartaFueraDeLaHoja(tester, t, 'Elige empresa', 'lista de empresas');
        lista(tester, 'Elige empresa', ['Sobusa', 'Coolitoral'],
            'lista de empresas');

        await tester.tap(find.text('Sobusa'));
        await tester.pumpAndSettle();
        expect(guia.state.step, MapGuideStep.route);
        enZonaSegura(tester, t, 'ruta');
        cartaFueraDeLaHoja(tester, t, 'Elige tu ruta', 'ruta');
        expect(
            contiene(pintor(tester).hole, tester.getRect(find.byKey(rutaKey))),
            isTrue,
            reason: 'ruta: la fila queda fuera');
        expect(
            tester
                .getRect(find.byKey(empresaKey))
                .overlaps(pintor(tester).hole),
            isFalse,
            reason: 'ruta: la empresa también queda iluminada');

        await tester.tap(find.byKey(rutaKey));
        await tester.pumpAndSettle();
        enZonaSegura(tester, t, 'lista de rutas');
        cartaFueraDeLaHoja(tester, t, 'Elige ruta', 'lista de rutas');
        lista(tester, 'Elige ruta', ['Ruta 106', 'Ruta 107', 'Ruta 108'],
            'lista de rutas');

        await tester.tap(find.text('Ruta 106'));
        await tester.pumpAndSettle();
        expect(guia.state.step, MapGuideStep.launchBuses);
        enZonaSegura(tester, t, 'ver buses');
        cartaFueraDeLaHoja(tester, t, 'Elige tu ruta', 'ver buses');
        expect(
            contiene(pintor(tester).hole, tester.getRect(find.byKey(verKey))),
            isTrue,
            reason: 'ver buses: el botón queda fuera');
        expect(
            tester.getRect(find.byKey(rutaKey)).overlaps(pintor(tester).hole),
            isFalse,
            reason: 'ver buses: la ruta también queda iluminada');
      });
    }
  }
}
