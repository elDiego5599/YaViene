# Lo que falta

Al 2026-10-02. Todo lo que se podía hacer desde aquí sin esperar a nadie ya
está hecho y en `main` de los tres repos. Lo que queda está repartido según
de quién depende. Cuando algo se cierre, se borra de aquí; cuando aparezca
algo nuevo, se apunta en su grupo.

El detalle de cada tarea (dónde, qué cambia, cómo se prueba) sigue en las
fichas de `plan-remediacion.md` (§4), en la raíz del workspace. Los nombres
tipo T4.1 o D2 son los de ese plan.

## Esperando a alguien de afuera

Nada de esto se fuerza; se retoma cuando llegue la respuesta o la cuenta.

- **La respuesta del AMB a la PQRS (D2).** Mientras no llegue, está quieta
  toda la ingesta desde el GPS de verdad: recibir las posiciones del equipo
  del bus, autenticar cada equipo, las rutas nuevas (T4.1–T4.3, T4.5–T4.7 y
  T11.1).
- **La cuota de GitHub Actions** (se agotó el 2026-09-19). Hasta que se
  renueve, la CI no arranca y lo verificado en local no se puede ver en
  verde allá (T1.8, T8.4 y la confirmación de T8.7–T8.9).
- **El secreto `BACKEND_REPO_TOKEN`** en el repo. Sin él, la CI no puede
  vigilar sola el contrato entre la app y el backend ni el socket del panel
  (T8.5 paso 3 y T8.6).
- **La cuenta de monitoreo** (T10.2). Lo que se usa ya está decidido (D10);
  falta crear la cuenta para enterarse de que el backend se cayó sin tener
  que mirarlo.
- **La consola de Firebase** (T3.13): borrar lo que quedó de las cuentas
  viejas del pasajero, con tu sesión.
- **Las cuentas de las tiendas** (T5.7), para subir las fichas.
- **La cuenta de Apple Developer** (99 USD al año). Sin ella no hay APNs,
  así que en iPhone el aviso sigue sonando solo con la app abierta. Cuando
  exista: la clave de APNs en la consola de Firebase, la capacidad de push
  en Xcode y quitar el «solo Android» de `avisos_push.dart` y de la
  privacidad.

## Lo que tienes que decidir tú

- **Reiniciar el backend vivo con el arreglo del aviso tarde y el buzón.**
  El servidor ya vigila los avisos desde que se arman, sin esperar el
  minuto del arriendo que los hacía llegar a 700 m (D13; migración 25), y
  recibe los reportes del buzón de la app (D14; migración 26). Está en
  `main` pero el backend vivo sigue con la versión vieja hasta que digas que
  sí: `npm run build` y `launchctl kickstart -k gui/$UID/com.yaviene.backend`.
  Sin el reinicio, el buzón de la app responde que no pudo enviar.
- **CARTO u OSM en el panel** (T6.11). Si es CARTO hace falta una cuenta y
  una clave; si es OSM, se queda como está y se cierra.
- **El aviso de Gradle que queda (AUD-24).** Sale de `maplibre_gl`, que por
  regla no se sube. Se queda así a menos que cambies esa regla.
- **NEW-27**: si se revisa cómo se arrastra la hoja de distancia.
- **NEW-36**: la revisión del flujo entero del pasajero (bienvenida,
  aceptar las políticas, las tarjetas y sus textos). La aplazaste a
  propósito; queda aquí para cuando quieras abrirla.
- **La Ley 1581 con un abogado** (T3.15). Son seis puntos pendientes. No
  frena la demo, pero tiene que estar resuelto antes de recoger datos reales
  de empresas o de pasajeros. Ahora entra también la privacidad del
  2 de octubre (versión 4): con un aviso armado en Android, el punto de
  espera redondeado y el código de Firebase quedan en el servidor hasta
  tres horas. Y el buzón (D14): el texto libre del reporte puede traer un
  dato personal aunque la app pida que no; se guarda solo hasta que sale
  por correo, y luego vive en el Gmail del equipo.

## Lo que tienes que hacer tú

Necesitan un teléfono, una cuenta o estar presente.

- **El correo del buzón** (D14). La contraseña de aplicación que pegaste en
  el chat el 2026-10-02 hay que darla por perdida: revócala en tu cuenta de
  Google (Seguridad → Contraseñas de aplicaciones) y crea otra. Pon en
  `YaVieneBackend/local.env` `YA_VIENE_CORREO_USUARIO` (el Gmail que manda),
  `YA_VIENE_CORREO_CLAVE` (la contraseña nueva) y, si quieres que llegue a
  otra dirección, `YA_VIENE_CORREO_DESTINO`. Luego el reinicio de arriba.
  Hasta entonces los reportes esperan en la cola y no se pierden; los pasos
  están en `docs/runbook.md` («Buzón de problemas y sugerencias»).

- **Android 15** (T5.5): correr la app en un emulador de Android 15 y
  declarar el tipo de servicio en Play Console.
- **La matriz de teléfonos** (T5.8): probar en los teléfonos de verdad.
- **Rendimiento en un teléfono físico** (T7.4, T7.5 y T7.9): perfilar con
  DevTools, hacer cien cambios de ruta mirando la memoria y dejar una hora
  corriendo con carga mirando el `heap`.
- **Batería** (T7.8): una hora con la app siguiendo un bus.
- **Lectores de pantalla**, con el guion al lado: TalkBack, VoiceOver en el
  iPhone y en el Mac, y el Narrador de Windows.
- **El panel en un Windows de verdad**: que la contraseña guardada funcione
  y que vaya fluido.
- **Las fichas de las tiendas** (T5.7): textos, capturas y video.
- **El video de respaldo del pitch** (T10.4), por si el día falla la red.
- **Mirar el tráfico real un rato** para fijar el umbral de latencia de la
  alerta (T7.1).
- **Probar en un Android de verdad los avisos con la app cerrada** (D13; el
  backend vivo ya tiene la clave de FCM desde el 2026-10-02): instalar la
  APK nueva, armar un aviso, cerrar la app del todo y esperar a que el bus
  llegue. Tiene que sonar «Tu bus de la ruta X está cerca de ti» con el
  bus a unos 900–1.000 m (tras reiniciar el backend vivo), una sola vez, y
  `/api/metrics` contar un `push.enviados`. Con la misma APK: que tocar la
  notificación abra el mapa en esa empresa, esa ruta y ese bus, con la
  cámara encima (también con la app cerrada); que el pin puesto a mano siga
  ahí al volver a abrir la app aunque haya GPS, y que tocar un bus en el
  mapa acierte a la primera, como en el iPhone. Instalada de cero, el mapa
  saluda una vez y deja escoger entre ver la guía o ir directo a la app.

## Lo que puedo hacer yo

Nada por ahora.

Ojo con la web: el CSS va en 117,8 de 121 KB y la carpeta `dist` en 772 de
797. Cualquier cambio de la web se mide antes de sumarlo.

## El día antes y el día del pitch

1. **El día anterior, no antes**: desplegar el respaldo en Fly y cargarle
   los datos (T2.3 y T2.4).
2. **Con Fly arriba**: matar ngrok tres veces y cronometrar que el pasajero
   y el panel se pasan solos al respaldo en 45 s o menos (simulacro a de
   T10.5).
3. **El repaso del día anterior, el día mismo y lo de después** (T10.6,
   T10.7 y T10.8). `check-demo.sh` revisa todo lo que se puede revisar solo.

## Después

Una **auditoría con ojos frescos**, en una sesión nueva sin este contexto, con
el prompt de `archivo/prompt-revision.md` (en la raíz del workspace). Si
encuentra algo grave, entra aquí antes de dar el plan por cerrado.
