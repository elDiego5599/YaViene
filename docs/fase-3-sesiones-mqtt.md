# Ya Viene: Fase 3, sesiones y ownership MQTT

Fecha: 2026-08-04
Estado: implementada y verificada

## Objetivo

Impedir que una conexion MQTT antigua pueda seguir publicando o borrar la
posicion de una conexion nueva para el mismo bus.

## Cambios Implementados

- Nueva tabla `driver_sessions` en SQLite.
- Cada login crea un `sessionId` unico.
- El JWT contiene el `sessionId`.
- Crear una sesion nueva revoca las sesiones activas del mismo conductor o
  bus.
- MQTT reclama el `clientId` para la sesion durante `authenticate`.
- Una sesion no puede ser reclamada por dos `clientId` distintos.
- `authorizePublish` verifica que la sesion siga activa y sea dueña del
  `clientId`.
- Una sesion revocada deja de publicar aunque su TCP siga conectado.
- La desconexion libera el `clientId` solo si coincide con la sesion activa.
- La posicion actual guarda `session_id`.
- `removePositionOwned` elimina solamente si coinciden bus y sesion.
- El cierre HTTP revoca siempre la sesion autenticada.
- La desconexion MQTT solo elimina la posicion perteneciente a esa sesion.
- El cliente MQTT del conductor usa el mismo `clientId` en constructor y
  `MqttConnectMessage`.

## Flujo De Sesion

```text
login
  -> revocar sesiones anteriores del conductor/bus
  -> crear sessionId activo
  -> firmar JWT
  -> MQTT authenticate
  -> reclamar clientId
  -> publicar posiciones con sessionId
```

## Comportamiento Ante Dos Sesiones

| Situacion | Resultado |
|---|---|
| Primera sesion conecta | Puede publicar |
| Segunda sesion inicia login | Revoca la primera |
| Primera sesion intenta publicar | Rechazada |
| Primera sesion se desconecta | No elimina el bus de la segunda |
| Segunda sesion publica | Posicion queda asociada a segunda sesion |
| Segunda sesion se desconecta | Bus se elimina si la posicion le pertenece |

## Esquema De Sesiones

| Columna | Uso |
|---|---|
| `session_id` | Identificador del login operativo |
| `driver_id` | Conductor asociado |
| `phone_number` | Compatibilidad transitoria |
| `company_id` | Empresa de la sesion |
| `bus_id` | Bus dueño de la sesion |
| `route_id` | Ruta asignada |
| `client_id` | Conexion MQTT que reclama la sesion |
| `status` | `active` o `revoked` |
| `created_at` | Inicio de sesion |
| `last_seen_at` | Ultima actividad autorizada |
| `revoked_at` | Momento de revocacion |

## Pruebas Ejecutadas

- Primera sesion MQTT autenticada y publicada.
- Segunda sesion para el mismo bus autenticada.
- Primera sesion revocada automaticamente.
- Publicaciones posteriores de la primera sesion rechazadas.
- Posicion final perteneciente a la segunda sesion.
- Desconexion de la primera sesion sin borrar la posicion vigente.
- Desconexion de la segunda sesion eliminando el bus.
- Verificacion de `404` despues de la ultima desconexion.
- Backend `npm run build`: PASS.
- Backend `npx tsc --noEmit`: PASS.
- Conductor `flutter analyze lib`: PASS.
- Test del conductor: PASS.

## Limitaciones Pendientes

- El `driverId` sigue derivandose temporalmente del telefono.
- Todavia no existe una tabla formal de asignaciones.
- No hay heartbeat de sesion separado del trafico MQTT.
- No existe limpieza automatica de sesiones antiguas.
- MQTT sigue sin TLS.
- El buffer offline aun no usa esta secuencia para deduplicar.
- La reconexion del pasajero aun debe restaurar sus rooms.

## Criterio De Salida

La Fase 3 se considera cerrada porque el ownership del bus ya esta asociado a
una sesion persistente y las desconexiones antiguas no pueden retirar el
estado de una sesion nueva.

La siguiente fase debe rediseñar el buffer offline para utilizar `sessionId`,
`sequence` y confirmaciones, evitando duplicados y perdida de datos.
