import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_pasajero/features/map/presentation/widgets/eta_bottom_sheet.dart';

void main() {
  group('alertToggleFeedback (tick "AVISADO ✓")', () {
    test('al armar el aviso devuelve true (muestra el tick)', () {
      expect(
        EtaBottomSheet.alertToggleFeedback(
          wasActive: false,
          nowActive: true,
        ),
        true,
      );
    });

    test('al desarmar devuelve false (quita el tick de inmediato)', () {
      expect(
        EtaBottomSheet.alertToggleFeedback(
          wasActive: true,
          nowActive: false,
        ),
        false,
      );
    });

    test('sin cambio de estado devuelve null (sin tick)', () {
      expect(
        EtaBottomSheet.alertToggleFeedback(
          wasActive: false,
          nowActive: false,
        ),
        isNull,
      );
      expect(
        EtaBottomSheet.alertToggleFeedback(
          wasActive: true,
          nowActive: true,
        ),
        isNull,
      );
    });
  });
}