# Ya Viene: Fase 1, contratos e invariantes

Fecha: 2026-08-04
Estado: contrato definido, implementacion pendiente

## Proposito

Esta fase define el lenguaje comun entre conductor, backend, MQTT, Socket.io,
SQLite y pasajero. No se deben implementar cambios de seguridad o persistencia
antes de respetar este contrato.

## Identificadores Canonicos

| Concepto | Nombre canonico JSON | Nombre interno SQL |
|---|---|---|
| Empresa | `companyId` | `company_id` |
| Conductor | `driverId` | `driver_id` |
| Bus | `busId` | `bus_id` |
| Ruta | `routeId` | `route_id` |
| Sesion | `sessionId` | `session_id` |
| Secuencia | `sequence` | `sequence` |
| Captura GPS | `capturedAt` | `captured_at` |
| Recepcion backend | `receivedAt` | `received_at` |
| Ghost | `isGhost` | `is_ghost` |

El telefono del conductor no forma parte de la identidad publica de una
posicion. Puede existir como dato privado de autenticacion, pero no debe
enviarse al pasajero.

## Compatibilidad MQTT Actual

Durante la primera migracion se conserva el prefijo actual para no romper los
APK existentes:

```text
empresa/{companyId}/bus/{busId}/posicion
```

El segmento `empresa` es parte del protocolo vigente. El identificador que
contiene debe tratarse internamente como `companyId`. No se permitira aceptar
topics alternativos en produccion sin una politica de compatibilidad explicita.

El `busId` del topic y el `companyId` del JWT son autoridad. El payload no
puede reemplazarlos.

## Contrato De Ingreso De Posicion

El conductor envia unicamente datos de medicion:

```json
{
  "protocolVersion": 1,
  "lat": 10.987,
  "lon": -74.812,
  "heading": 90.0,
  "speedKmh": 30.0,
  "capturedAt": 1785859092000,
  "sequence": 1234
}
```

No se aceptan desde el payload de ingreso:

- `phoneNumber`.
- `driverId`.
- `companyId`.
- `busId`.
- `routeId`.
- `isGhost`.
- `receivedAt`.

Esos valores se derivan del JWT, del topic, de la asignacion activa o del
backend.

## Contrato De Posicion Publica

El backend entrega al pasajero:

```json
{
  "protocolVersion": 1,
  "eventId": "evt_01J...",
  "busId": "B-042",
  "companyId": "EMP-01",
  "routeId": "R-101",
  "lat": 10.987,
  "lon": -74.812,
  "heading": 90.0,
  "speedKmh": 30.0,
  "capturedAt": 1785859092000,
  "receivedAt": 1785859092500,
  "sequence": 1234,
  "isGhost": false
}
```

El pasajero no recibe `driverPhone`, JWT, credenciales ni datos privados del
conductor.

## Contrato De Eventos Socket.io

Se conservan los nombres actuales durante la migracion:

| Evento | Direccion | Payload |
|---|---|---|
| `subscribe:route` | pasajero -> backend | `{ routeId, companyId }` |
| `unsubscribe:route` | pasajero -> backend | `{ routeId, companyId }` |
| `positions:batch` | backend -> pasajero | `{ routeId, companyId, buses[] }` |
| `bus:position` | backend -> pasajero | posicion publica |
| `bus:left` | backend -> pasajero | `{ eventId, busId, routeId, companyId, reason, occurredAt }` |
| `server:error` | backend -> cliente | error canonico |

El cliente debe tratar `bus:left` como idempotente. Recibir dos veces el mismo
`eventId` no debe generar un segundo efecto.

## Contrato De Error

Las respuestas HTTP y los errores de protocolo deben seguir esta forma:

```json
{
  "error": {
    "code": "POSITION_INVALID_COORDINATES",
    "message": "La posicion GPS no es valida",
    "requestId": "req_01J..."
  }
}
```

Los codigos no deben depender del texto visible. El mensaje puede traducirse;
el codigo debe permanecer estable para logs, tests y aplicaciones.

## Claims JWT Canonicos

El token de conductor debera contener como minimo:

```json
{
  "sub": "driver_123",
  "role": "driver",
  "companyId": "EMP-01",
  "busId": "B-042",
  "routeId": "R-101",
  "sessionId": "ses_01J...",
  "iat": 1785859092,
  "exp": 1785945492,
  "iss": "ya-viene-backend",
  "aud": "ya-viene-mqtt"
}
```

El claim `sub` identifica al conductor. El telefono deja de ser el identificador

El servidor debe rechazar tokens con:

- Firma invalida.
- Expiracion vencida.
- `role` no permitido.
- `iss` incorrecto.
- `aud` incorrecto.
- Empresa, bus o ruta incompatibles con la sesion.

## Invariantes De Identidad

1. La identidad siempre proviene del token autenticado.
2. El payload MQTT nunca puede cambiar el conductor autenticado.
3. El topic nunca puede apuntar a un bus distinto al del token.
4. Una sesion activa solo puede publicar para un bus.
5. Un bus no puede tener dos sesiones activas sin una politica explicita.
6. Una desconexion solo puede retirar la sesion que realmente se desconecto.
7. Un pasajero nunca puede ejecutar operaciones de conductor.
8. Un pasajero nunca recibe credenciales ni telefono del conductor.

## Invariantes De Posicion

1. `lat` debe estar entre -90 y 90.
2. `lon` debe estar entre -180 y 180.
3. `speedKmh` debe ser mayor o igual a cero.
4. `heading` debe estar entre 0 y 360 o ser normalizado.
5. `sequence` debe aumentar por sesion y bus.
6. Una posicion vieja no puede sobrescribir una posicion nueva.
7. `capturedAt` debe estar dentro de una ventana de skew aceptable.
8. `receivedAt` siempre lo genera el backend.
9. La posicion debe pertenecer a la asignacion vigente.
10. El backend debe deduplicar reintentos del mismo `sequence`.

## Maquina De Estados Del Bus

```text
offline -> online -> ghost -> removed
              ^        |
              |        |
              +--------+
```

Transiciones validas:

| Estado actual | Evento | Estado siguiente |
|---|---|---|
| offline | posicion aceptada | online |
| online | timeout ghost | ghost |
| ghost | posicion aceptada | online |
| online | timeout removal | removed |
| ghost | timeout removal | removed |
| online/ghost | cierre de turno | removed |
| online/ghost | desconexion valida | removed |
| removed | posicion nueva de sesion valida | online |

Los eventos de transicion deben ser idempotentes y tener `eventId`.

## Ventanas Temporales Canonicas

Los valores deben existir en una sola fuente de configuracion:

| Regla | Valor inicial |
|---|---:|
| Intervalo de sweep | 10 s |
| Entrada a ghost | 30 s sin posicion aceptada |
| Remocion | 60 s sin posicion aceptada |
| Skew maximo de captura futura | 30 s |
| Edad maxima de replay aceptable | Definir en Fase 6 |

No debe existir otra interpretacion en Dart, TypeScript, mocks o documentacion.

## Incompatibilidades Detectadas En El Codigo Actual

| Area | Actual | Canonico | Accion posterior |
|---|---|---|---|
| Identidad | `phoneNumber` | `driverId` en JWT | Fase 2 y 3 |
| Empresa | `empresaId` | `companyId` | Migracion controlada |
| Timestamp | `timestamp` ISO externo y INTEGER interno | `capturedAt`/`receivedAt` INTEGER | Fase 5 y 6 |
| Ghost Dart | `isGhostBus` | `isGhost` | Unificar modelo |
| Ghost render | `shouldShowAsGhost` | `isGhostBus` recibido | Corregir mapa |
| MQTT payload | Incluye `phoneNumber` | Solo medicion | Fase 3 |
| REST GPS | No exige JWT | Identidad derivada del JWT | Fase 2 |
| Socket registro | `driver:register` publico | Solo canal administrativo | Fase 2 |
| Rutas | Mocks duplicados | Fuente backend | Fase 10 |
| ETA | Valores fijos | Calculo real | Fase 11 |

## Alcance De Esta Fase

Esta fase define el contrato. No implementa aun:

- Middleware JWT.
- Migraciones SQL.
- ACK offline.
- Cambio de topic.
- Cambio de schema Dart.
- Servicio background.
- ETA.

Esas implementaciones se ejecutaran en fases separadas y deberan respetar este
documento.

## Criterio De Salida

Fase 1 queda aprobada cuando:

- El contrato esta versionado.
- Las incompatibilidades actuales estan enumeradas.
- Los campos canonicos estan definidos.
- Los invariantes de identidad y posicion estan definidos.
- Las transiciones del bus estan definidas.
- No existe ambiguedad entre `isGhost`, `isGhostBus`, `timestamp` y
  `capturedAt`.
- Fase 2 puede implementar autenticacion sin inventar nuevos nombres ni
  reglas.
