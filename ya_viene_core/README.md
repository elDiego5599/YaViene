# Ya Viene · Core

Paquete Dart compartido por `app_pasajero`, `app_control` y `app_conductor`: modelos de dominio, providers base de Riverpod, tema visual y widgets comunes. No es una app, no se ejecuta por su cuenta.

## Qué expone

Todo se importa desde el barrel `package:ya_viene_core/ya_viene_core.dart`:

* **Modelos** (`lib/core/models/`): `BusPosition`, `BusStop`, `Company`, `ConnectionStatus`, `RouteInfo`, `RouteTrajectory`.
* **Providers** (`lib/core/providers/`): estado base de Riverpod compartido entre apps (`app_providers.dart`, `map_providers.dart`).
* **Tema** (`lib/core/theme/app_theme.dart`): paleta y estilos institucionales de Ya Viene.
* **Widgets** (`lib/shared/widgets/`): `PrimaryButton`, `PulsingDot`, `SelectionChip`, `InstitutionalDropdown`.

## Regla de dependencias

Este paquete **no debe depender de MapLibre, Mapbox ni MQTT directamente** (ver comentario en `pubspec.yaml`). Es estrictamente modelos de dominio puros y sistema de diseño visual — cualquier integración con mapas o transporte en tiempo real vive en las apps que lo consumen.

## Verificación

```bash
flutter analyze lib test
flutter test
```
