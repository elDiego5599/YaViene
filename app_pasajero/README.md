# Ya Viene — Pasajero

App Flutter del pasajero para ver buses en tiempo real, con guía de primer uso, avisos de proximidad y seguimiento en segundo plano.

> Arquitectura detallada: [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) (copia versionada de `/AGENTS.md`).

## Requisitos

- Flutter 3.x
- Android SDK (emulador `Pixel_10_Pro`, `emulator-5554`)
- Node 18+ para el backend
- `ngrok` con dominio fijo `occupy-shed-squatter.ngrok-free.dev`

## Backend + túnel

```bash
# En YaVieneBackend (repo separado, carpeta hermana ../YaVieneBackend)
set -a && source local.env && set +a
nohup node dist/index.js </dev/null > /tmp/yaviene-backend.log 2>&1 &
# ngrok ya configurado con dominio fijo -> https://occupy-shed-squatter.ngrok-free.dev (200 OK)
# No uses cloudflared: cambia la URL y obliga a recompilar.
```

## App pasajero

```bash
cd YaViene/app_pasajero
flutter pub get

# Run (dev, con backend ngrok)
flutter run --dart-define=BACKEND_URL=https://occupy-shed-squatter.ngrok-free.dev

# Tests unitarios
flutter analyze lib test
flutter test

# Fotos de referencia (goldens): 34 PNG en test/golden/goldens/.
# Comparan pixel a pixel la app contra la última foto aprobada.
flutter test test/golden

# Volver a tomar las fotos. SOLO cuando el cambio visual es a propósito,
# y el commit tiene que decir qué cambió y por qué. Un golden actualizado
# sin explicación es una regresión aprobada a ciegas.
flutter test test/golden --update-goldens
git diff --stat test/golden/goldens   # revisa QUÉ se movió antes de commitear

# El candado del sistema de diseño. Cuenta los `TextStyle` con `fontSize` a
# mano y los `circular(` con número a mano, y falla si el número sube.
# Si migraste un archivo y bajó, baja también el techo en el mismo commit:
# lo ganado se cierra, no se deja abierto.
flutter test test/candado_estetica_test.dart

# Test integral (requiere emulador + backend + ngrok arriba)
flutter test integration_test/map_load_test.dart \
  -d emulator-5554 \
  --dart-define=BACKEND_URL=https://occupy-shed-squatter.ngrok-free.dev \
  --dart-define=DISABLE_MAP_GUIDE=true

# APK release
flutter build apk --release --dart-define=BACKEND_URL=https://occupy-shed-squatter.ngrok-free.dev
cp build/app/outputs/flutter-apk/app-release.apk ~/Desktop/APKs/YaViene-Pasajero.apk
~/Library/Android/sdk/platform-tools/adb install -r ~/Desktop/APKs/YaViene-Pasajero.apk
~/Library/Android/sdk/platform-tools/adb shell am start -n com.example.ya_viene_pasajero/.MainActivity
```

## Estructura

```
lib/
  core/           # Router, theme, utils (bus_labels, prefs); sin cuenta (D3)
  features/
    map/          # MapWidget (1030 líneas, delega a 5 módulos), guía, ETA
      presentation/
        providers/  # barrel providers.dart (8 providers)
        widgets/    # barrel widgets.dart (16 widgets)
          map_markers.dart, map_bus_animator.dart, halo_painter.dart, ...
          map_route_data.dart (part), alert_guards.dart, tap_debouncer.dart
        utils/    # bus_hit_test, geo, map_constants
    notifications/ # Proximity, historial, pantalla
  services/       # background_keep_alive
test/            # 109 tests: map_widgets, guide_flow, bus_hit, etc.
docs/            # ARCHITECTURE.md
```

## Lints

`analysis_options.yaml` incluye `flutter_lints` + `directives_ordering`, `file_names`, `lines_longer_than_80_chars`. Corre `dart fix --apply` y `dart format lib` antes de commitear. CI (`/.github/workflows/ci.yml`) corre `analyze` + `test` en cada push.

## Backend repo

El backend vive en repo separado `YaVieneBackend` (hermano de `YaViene/`). Ver su `README` para `docker-compose up` / `make dev` (Fase 21).
