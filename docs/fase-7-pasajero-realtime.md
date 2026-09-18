# Ya Viene: Fase 7, reconexion y consistencia del pasajero

Fecha: 2026-08-04
Estado: implementada y validada estaticamente

## Objetivo

Evitar que el pasajero quede conectado al socket pero sin recibir posiciones
despues de una perdida de red, y evitar que eventos de una ruta afecten otra.

## Cambios Implementados

- `RealtimeService` mantiene las rutas suscritas en memoria.
- Al ejecutar `onConnect`, vuelve a emitir cada `subscribe:route`.
- `connect()` no crea sockets duplicados si ya existe una conexion activa.
- El batch conserva `routeId` y `companyId` del evento original.
- El provider ignora batches de otras rutas.
- El provider ignora posiciones live de otra ruta.
- `bus:left` conserva su payload completo en lugar de perder `routeId`.
- `bus:left` de otra ruta se ignora.
- El mapa combina el flag backend `isGhostBus` con el fallback temporal local.
- `BusPosition.tryParse` exige timestamp ISO y descarta la posicion (null) si
  falta identidad o coordenada, si la fecha no se entiende o no cuadra, o si
  rumbo o velocidad no son finitos.
- `BusPosition.tryParse` lee el nombre canonico `isGhost`.
- `BusPosition.toJson` utiliza el nombre canonico `isGhost`.

## Flujo De Reconexion

```text
socket desconecta
  -> estado disconnected/reconnecting
  -> Socket.io reconecta
  -> onConnect
  -> restaurar subscribe:route
  -> recibir positions:batch
  -> continuar bus:position
```

## Contratos Verificados

| Flujo | Resultado |
|---|---|
| Batch de ruta activa | Procesado |
| Batch de otra ruta | Ignorado |
| Posicion live de ruta activa | Procesada |
| Posicion live de otra ruta | Ignorada |
| `bus:left` de ruta activa | Elimina bus |
| `bus:left` de otra ruta | Ignorado |
| Reconexion con ruta guardada | Re-suscripcion automatica |
| Ghost backend | Respetado por el mapa |
| Timestamp INTEGER | Compatible |
| Timestamp ISO | Compatible |

## Validaciones Ejecutadas

- `flutter analyze lib` del pasajero: PASS.
- `flutter analyze lib` del core: PASS.
- Backend y MQTT ya tenian ACK y ciclo de vida verificados en fases anteriores.

## Limitaciones Pendientes

- No existe aun una prueba automatizada con un servidor Socket.io falso que
  fuerce desconexion y reconexion.
- La UI continua actualizando el GeoJSON completo por posicion.
- No hay throttling visual para rafagas de eventos.
- El contrato de suscripcion sigue usando el string de ruta por compatibilidad;
  `companyId` debe incorporarse en la siguiente migracion de protocolo.
- La autenticacion del pasajero no protege todavia las suscripciones publicas.

## Criterio De Salida

La fase queda implementada porque el pasajero ya conserva y restaura sus
suscripciones, no mezcla rutas y consume el estado ghost canonico. La siguiente
fase debe atacar rendimiento y observabilidad. Las trayectorias y paradas quedan
fuera del alcance actual porque pueden cambiar por obras, desvios y trafico. En
el futuro, `ida/vuelta` se podra derivar del GPS sin convertir una trayectoria
estatica en autoridad del sistema.
