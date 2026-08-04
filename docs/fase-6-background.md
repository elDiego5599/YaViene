# Ya Viene: Fase 6, tracking en background

Fecha: 2026-08-04
Estado: implementada y verificada en emulador Android

## Objetivo

Hacer que GPS, MQTT, ACK, outbox y reconexion vivan en el foreground service,
no en el widget visible del dashboard.

## Arquitectura Nueva

```text
UI / GpsManager
  -> startService()
  -> invoke(startTracking, config)

BackgroundService isolate
  -> TrackingEngine
       -> Geolocator
       -> MqttService
       -> OfflineBufferRepository
       -> ACK y replay
       -> health check y reconexion
```

`GpsManager` quedo como adaptador de permisos, comandos y estado visual. El
pipeline de datos lo ejecuta `TrackingEngine` dentro del isolate del servicio.

## Cambios Implementados

- Nuevo `tracking_engine.dart` independiente de Riverpod y widgets.
- `TrackingEngine` posee GPS, MQTT, outbox, secuencias, ACK y timers.
- `GpsManager` inicia el foreground service y envia `TrackingConfig`.
- El servicio puede recibir `startTracking` y `stopTracking`.
- Estados del engine se devuelven a la UI mediante `trackingState`.
- El servicio no inicia automaticamente al arrancar la app.
- Se desactivo el inicio automatico en boot.
- Se configuro foreground type `location`.
- Se creo explicitamente el notification channel.
- Se solicito `POST_NOTIFICATIONS` en Android 13+.
- Se habilito core library desugaring requerido por notificaciones.
- El cierre de turno detiene el servicio completo.

## Validacion Android

Dispositivo usado:

sdk gphone16k arm64
Android 17 / API 37
emulator-5554
```

Pruebas realizadas:

- APK debug compilado con `BACKEND_URL=http://10.0.2.2:3000`.
- Instalacion exitosa mediante ADB.
- Provisionamiento de conductor en backend.
- Inicio de sesion en la app.
- Seleccion de bus y ruta.
- Inicio de transmision.
- Concesion de permiso de notificaciones.
- Concesion de ubicacion precisa.
- Concesion de ubicacion permanente.
- Foreground service activo con `foregroundId=888`.
- Notification channel `yaviene_conductor_channel` activo.
- App enviada a background sin detener el servicio.
- Sin `RemoteServiceException` despues de corregir el canal.
- Sin crash al iniciar el servicio.
- APK release compilado previamente y APK debug compilado despues del cambio.

## Resultado Observado

El servicio aparece activo en Android:

ServiceRecord ... BackgroundService
isForeground=true
foregroundId=888
foregroundNoti=Notification(channel=yaviene_conductor_channel)
```

El emulador no estaba produciendo una posicion GPS sintetica durante esta
prueba, por lo que la recepcion de una coordenada real queda pendiente de
inyectar una ubicacion mediante el emulador o usar un telefono fisico.

## Limitaciones Pendientes

- No se ha probado el reinicio del proceso completo con el servicio activo.
- No se ha probado cambio WiFi/datos moviles en telefono fisico.
- Android puede reiniciar el servicio mediante watchdog; esa politica aun no
  tiene una prueba de desastre automatizada.
- La plataforma objetivo es Android; iOS no se considera soporte de tracking
  continuo.
- El proceso de UI y el isolate pueden compartir proceso Android, pero el
  engine ya no depende de la vida del widget.

## Criterio De Salida

La fase queda implementada porque el servicio foreground inicia correctamente,
mantiene el engine separado del dashboard y permanece activo cuando la app
pasa a background. El siguiente nivel de validacion requiere coordenadas
reales durante pantalla bloqueada y reinicio del proceso.
