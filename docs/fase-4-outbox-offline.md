# Ya Viene: Fase 4, outbox offline y ACK de aplicacion

Fecha: 2026-08-04
Estado: implementada y verificada parcialmente con backend y simulador

## Objetivo

Evitar que una posicion se pierda cuando MQTT falla y evitar que las
posiciones ya entregadas se reproduzcan indefinidamente cada diez segundos.

## Problema Anterior

El conductor guardaba todas las posiciones aunque MQTT funcionara, las
publicaba en vivo y luego las reproducia desde el buffer. Ademas, el buffer
limpiaba la tabla completa al terminar un replay, incluyendo posiciones nuevas
creadas durante la sincronizacion.

## Diseño Nuevo

Cada posicion local tiene:

| Campo | Funcion |
|---|---|
| `id` | Identidad local del outbox |
| `sequence` | Orden monotono de la posicion |
| `timestamp` | Momento de captura local |
| `status` | `pending` o `sending` |
| `attempts` | Numero de intentos |
| `lastError` | Ultimo error conocido |
| `lastAttemptAt` | Momento del ultimo intento |

El flujo es:

```text
GPS
  -> guardar con status sending
  -> publicar MQTT
  -> esperar ACK de aplicacion
  -> eliminar solo ese id si hubo ACK
  -> volver a pending si no hubo ACK
```

El replay utiliza lotes de 20 posiciones y elimina exclusivamente los IDs que
recibieron ACK. Las posiciones creadas durante el replay no son eliminadas.

## ACK MQTT

El backend publica ACK en:

```text
empresa/{companyId}/bus/{busId}/ack
```

Payload:

```json
{
  "protocolVersion": 1,
  "sessionId": "sesion",
  "sequence": 1234,
  "accepted": true,
  "reason": null,
  "receivedAt": 1785865704618
}
```

El broker solo permite suscribirse al ACK correspondiente al bus autenticado.

Resultados:

| Resultado backend | Accion local |
|---|---|
| `accepted: true` | Eliminar posicion del outbox |
| `accepted: false` | Eliminarla como rechazada y registrar razon |
| Sin ACK | Mantenerla como `pending` |
| Desconexion | Completar espera sin ACK y mantener pendiente |
| Reintento duplicado | Backend responde `DUPLICATE` y se elimina localmente |

## Secuencias

- El conductor conserva la siguiente secuencia en SQLite local.
- Las secuencias sobreviven reinicios de la app.
- Filas antiguas sin secuencia reciben una secuencia durante la migracion.
- El backend guarda `captured_at`, `sequence` y `session_id`.
- La deduplicacion es por bus y sesion.
- Una sesion nueva puede comenzar su secuencia nuevamente.

## Backend

- El payload MQTT ya no necesita `phoneNumber`.
- Se validan `protocolVersion`, `capturedAt`, `sequence` y coordenadas basicas.
- Las posiciones duplicadas reciben ACK `accepted:true` con razon `DUPLICATE`.
- Las posiciones rechazadas por sanity reciben ACK `accepted:false`.
- El ACK no se emite para payloads sin secuencia valida.

## Pruebas Ejecutadas

- Backend build y TypeScript: PASS.
- Flutter analyze del conductor: PASS.
- Test del conductor: PASS.
- Simulador MQTT autenticado: PASS.
- Suscripcion al topic ACK: PASS.
- Posicion valida: ACK `accepted:true`.
- Posicion rechazada por sanity: ACK `accepted:false` y razon.
- Posicion persistida con secuencia: PASS.
- Desconexion MQTT posterior: bus eliminado por ownership de sesion.

## Limitaciones Pendientes

- La prueba de persistencia del outbox en un dispositivo Android real queda
  pendiente de ejecutar con perdida de red prolongada.
- Aun no existe una prueba automatizada que mate el proceso entre envio y ACK.
- El sanity check continua usando tiempo de recepcion; la correccion completa
  de tiempo de captura corresponde a la siguiente fase.
- La app sigue usando `distanceFilter: 0`, por lo que puede generar demasiadas
  posiciones.
- El ACK viaja por MQTT sin TLS.

## Criterio De Salida

La Fase 4 se considera implementada porque la entrega ya tiene identificadores,
ACK de aplicacion, deduplicacion y eliminacion selectiva. La validacion final
en telefono fisico debe comprobar apagado de pantalla, perdida de red,
reinicio de proceso y posterior replay sin perdida.

La siguiente fase debe corregir timestamps, ordenamiento y sanity check para
que un replay offline no sea interpretado como una velocidad imposible.
