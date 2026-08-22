# Ya Viene · Panel de Control de Flota

Aplicación de escritorio (macOS / Windows / Linux) para administradores de empresas de transporte. Permite monitorear la flota de buses en tiempo real sobre el mapa, gestionar el catálogo de rutas y buses, y controlar la visibilidad pública de cada unidad hacia los pasajeros.

## Ejecución Local

```bash
# Ejecutar en macOS (desarrollo local con backend en localhost:3000)
flutter run -d macos

# Ejecutar apuntando al backend de demo / producción
flutter run -d macos --dart-define=BACKEND_URL=https://occupy-shed-squatter.ngrok-free.dev
```

## Credenciales por Defecto (Demo)

* **Usuario**: `admin`
* **Contraseña**: `admin123`

## Arquitectura y Documentación

Para ver el diseño técnico, flujo de datos por WebSockets/REST y arquitectura del panel de control, consulta [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Verificación

```bash
# Análisis estático
flutter analyze lib test

# Pruebas unitarias y de widgets
flutter test
```
