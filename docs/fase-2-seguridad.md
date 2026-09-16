# Ya Viene: Fase 2, autenticacion y autorizacion

Fecha: 2026-08-04
Estado: implementada y verificada en backend y simulador

## Cambios Implementados

- `POST /api/admin/drivers` requiere `x-admin-key`.
- `POST /api/drivers/register` queda como alias administrativo y tambien
  requiere `x-admin-key`.
- El provisionamiento guarda PIN con `scrypt`, nunca en texto plano.
- `POST /api/auth/login` valida telefono, PIN y asignacion de bus/ruta.
- JWT incluye `sub`, `driverId`, `companyId`, `busId`, `routeId` y `sessionId`.
- JWT valida issuer `ya-viene-backend` y audience `ya-viene-mqtt`.
- En produccion el backend falla si no existe `JWT_SECRET`.
- `POST /api/gps` queda deshabilitado para evitar un bypass del canal MQTT.
- `/api/buses/:busId/offline` requiere JWT del bus correspondiente.
- `GET /api/drivers/:phone` requiere admin o el propio conductor.
- Socket.io ya no permite `driver:register`.
- Las respuestas publicas de posiciones ya no incluyen `driverPhone`.
- MQTT usa exclusivamente la identidad validada del JWT, no el telefono del
  payload de posicion.
- MQTT valida que la asignacion persistida coincida con el token.
- La desconexion MQTT solo elimina una posicion compatible con la identidad
  autenticada.
- El parser HTTP limita cuerpos a 32 KB y rechaza JSON invalido con `400`.
- El simulador ahora provisiona con clave administrativa, inicia sesion y
  soporta JWTs MQTT de mas de 255 bytes.
- `/api/auth/login` valida el PIN antes de entregar el token del turno.
- El cierre de turno envia el Bearer token al endpoint offline.

## Variables Requeridas

Desarrollo:

```text
JWT_SECRET=un-secreto-local
ADMIN_API_KEY=una-clave-administrativa-local
```

Produccion:

- `JWT_SECRET` obligatorio.
- `ADMIN_API_KEY` obligatorio para provisionamiento.
- Ambas variables deben venir del gestor de secretos del entorno.
- No deben incluirse en APKs, repositorios ni scripts versionados.

## Provisionamiento De Un Conductor

Ejemplo local:

```bash
ADMIN_KEY='una-clave-administrativa-local'  # gitleaks:allow
curl -X POST http://localhost:3000/api/admin/drivers \
  -H 'Content-Type: application/json' \
  -H "x-admin-key: $ADMIN_KEY" \
  -d '{
    "phoneNumber": "3000000000",
    "name": "Conductor de prueba",
    "pin": "1234",
    "companyId": "EMP-01",
    "busId": "B-042",
    "routeId": "R-101"
  }'
```

El conductor posteriormente solicita un token mediante:

```bash
curl -X POST http://localhost:3000/api/auth/login \
  -H 'Content-Type: application/json' \
  -d '{
    "phoneNumber": "3000000000",
    "pin": "1234",
    "busId": "B-042",
    "routeId": "R-101"
  }'
```

## Pruebas Ejecutadas

| Prueba | Resultado |
|---|---|
| Provisionamiento sin clave administrativa | `401` |
| Provisionamiento con clave administrativa | `201` |
| Login con PIN incorrecto | `401` |
| Login correcto | `200` y JWT valido |
| HTTP GPS sin autenticacion | `410`, canal deshabilitado |
| Offline sin JWT | `403` |
| MQTT con JWT valido | Posicion aceptada |
| Topic MQTT correcto | Autorizado |
| Topic MQTT incorrecto | Rechazado |
| Payload publico de posicion | No contiene telefono |
| Offline con JWT del bus | `200` |
| Posicion despues de offline | `404` |
| JWT largo en simulador | CONNACK valido |

## Compatibilidad Transitoria

Durante esta fase `driverId` se deriva temporalmente del telefono para poder
migrar los registros actuales. Esto no es el modelo final. La separacion
completa entre identidad del conductor, telefono y asignacion queda pendiente
de la fase de dominio y migraciones.

El topic conserva el formato actual:

```text
empresa/{companyId}/bus/{busId}/posicion
```

## Riesgos Que Permanecen

- MQTT sigue utilizando TCP sin TLS; MQTTS corresponde a una fase posterior.
- No existe todavia rate limiting de login ni de provisionamiento.
- No existe revocacion persistente de sesiones JWT.
- La asignacion esta en la tabla de drivers y aun no existe una tabla formal de
  asignaciones.
- El bus puede tener mas de una sesion hasta completar la fase de sesiones.
- El buffer offline todavia tiene el comportamiento anterior y sera corregido
  en su propia fase.
- El servicio background aun no controla el pipeline GPS completo.

## Criterio De Salida

Fase 2 se considera cerrada porque las mutaciones principales ya requieren
autorizacion, el canal MQTT usa identidad autenticada, el conductor usa login
real y las pruebas positivas y negativas fueron reproducidas.

La siguiente fase debe resolver sesiones MQTT y ownership de bus antes de
implementar el buffer offline, para que los reintentos no puedan publicar o
eliminar el estado de otra sesion.
