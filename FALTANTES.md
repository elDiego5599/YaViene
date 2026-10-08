# Lo que falta

Al 2026-10-07. Todo lo que se podía hacer desde aquí sin esperar a nadie ya
está hecho y subido a las ramas de trabajo (`diseno-21st` en app y web,
`prueba` en el backend); a `main` se sube por lotes cuando lo pidas
(regla de trabajo 2 de `CLAUDE.md`). Lo que queda está repartido según
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
  privacidad. El iPhone sale cuando haya push remoto (dueño, 2026-10-06):
  por eso su nota ya no pide dejar la app abierta y dice a qué distancia
  avisa, con su «Cambiar».

## Lo que tienes que decidir tú

- **Dónde se sirve el panel en el navegador.** El panel ya corre también
  en web (además de macOS y Windows). Su sesión va en una cookie
  `SameSite=Strict`, así que el panel tiene que servirse en el mismo sitio
  que la API: dos subdominios de `ngrok-free.dev` cuentan como sitios
  distintos (está en la Public Suffix List), y ahí la cookie no viaja. Hace
  falta un dominio propio (por ejemplo `panel.` y `api.` del mismo) o
  servir el panel desde el mismo backend. Ese origen, y solo ese, va en
  `CORS_ORIGINS`. Es un despliegue: no lo hago sin que lo decidas.
  Probado entero en Chromium contra un backend temporal (2026-10-08).
  Se compila con `tool/compilar-panel-web.sh <API>`, que deja al lado
  `build/web/csp.txt`: la CSP que el servidor del panel tiene que mandar.

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

- **Probar el buzón** (D14): desde el menú de la APK nueva, mandar un
  problema y una sugerencia y ver que lleguen al Gmail (salen cada 30 s). Si no lo has hecho, revoca
  la contraseña de aplicación que pegaste en el chat el 2026-10-02.

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
  y que vaya fluido. Se descarga de la CI: Actions → «Ya Viene CI» → «Run
  workflow» con `backend_url`, y en la corrida el artefacto `panel-windows`
  (la carpeta entera; se abre `app_control.exe`).
- **Las fichas de las tiendas** (T5.7): textos, capturas y video.
- **El video de respaldo del pitch** (T10.4), por si el día falla la red.
- **Mirar el tráfico real un rato** para fijar el umbral de latencia de la
  alerta (T7.1).

## Lo que puedo hacer yo

- **La tarjeta del aviso activo con el texto al doble** (hallado el
  2026-10-07, ya estaba en `9d0f3a0`): con el aviso puesto y el texto del
  sistema al doble, en un 390×844 la hoja se pasa de la pantalla. En
  Android desborda 21 px y «Cambiar» queda en 861–892, fuera; en iPhone
  «Te avisamos a 1,0 km» se parte palabra por palabra junto a su
  «Cambiar» y el botón del aviso baja a 831–869. Medido con la letra de
  pruebas, que es más ancha que la de verdad; falta la prueba roja que lo
  ate y acomodarlo (la píldora debajo del texto con letra grande, como en
  `notifications_screen.dart:813`).

Ojo con la web: el CSS va en 120,2 de 121 KB y la carpeta `dist` en 781,6 de
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
