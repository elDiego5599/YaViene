# Ya Viene: Fase 9, seguridad operativa y transporte

Fecha: 2026-08-04
Estado: implementada en modo configurable

## Cambios

- Rate limiting de login: 5 intentos por IP/operacion cada 60 segundos.
- Rate limiting de provisionamiento: 20 intentos por IP/operacion cada 60
  segundos.
- `GET /api/ready` verifica SQLite y disponibilidad del broker MQTT.
- `GET /api/metrics` continua protegido por clave administrativa.
- TLS HTTP opcional mediante `HTTP_TLS_CERT_PATH` y `HTTP_TLS_KEY_PATH`.
- TLS MQTT opcional mediante `MQTT_TLS_CERT_PATH` y `MQTT_TLS_KEY_PATH`.
- HTTP, Socket.io y MQTT conservan modo local sin TLS para desarrollo.

## Variables TLS

Backend:

```text
HTTP_TLS_CERT_PATH=/ruta/cert.pem
HTTP_TLS_KEY_PATH=/ruta/key.pem
MQTT_TLS_CERT_PATH=/ruta/cert.pem
MQTT_TLS_KEY_PATH=/ruta/key.pem
```

Apps:

```bash
flutter build apk \
  --dart-define=BACKEND_URL=https://host:3000 \
  --dart-define=MQTT_USE_TLS=true
```

No se activaron certificados autofirmados en el entorno local. La activacion
de produccion requiere certificados validos, CA confiable y pruebas de
renovacion.

## Pruebas Ejecutadas

- `/api/ready` con SQLite y MQTT activos: `200 ready`.
- `/api/metrics` con clave admin: `200`.
- `/api/metrics` sin clave: `401`.
- Primeros cinco logins invalidos: `401`.
- Sexto login en ventana: `429`.
- Logs MQTT por paquete con debug apagado: cero.
- Backend build y TypeScript: PASS.
- Analyzer pasajero: PASS.

## Limitaciones

- El rate limiter es local al proceso y no distribuido.
- No existe Redis para rate limiting multiinstancia.
- TLS no se valido con certificados reales en esta maquina.
- El health endpoint sigue siendo liveness; readiness es `/api/ready`.
- Las metricas son en memoria y no sobreviven reinicios.

## Alcance Excluido

Esta fase no modifica trayectorias, paradas ni catalogos. La deteccion futura
de `ida/vuelta` debe derivarse del GPS y no depender de una geometria estatica.
