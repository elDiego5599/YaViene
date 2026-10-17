# Lo que falta

Al 2026-10-08. Todo lo que se podía hacer desde aquí sin esperar a nadie ya
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

- **CARTO u OSM en el panel** (T6.11). Si es CARTO hace falta una cuenta y
  una clave; si es OSM, se queda como está y se cierra.
- **El aviso de Gradle que queda (AUD-24).** Sale de `maplibre_gl`, que por
  regla no se sube. Se queda así a menos que cambies esa regla.
- **Las capturas de A2** (distancia por la ruta, 2026-10-08), en
  `capturas-a2/` en la raíz del workspace: en la B18, el mismo bus a
  614 m en recta (antes, que bloqueaba el aviso) y a 3,4 km por la ruta
  (ahora). Si no te convence, se revierte el commit de A2.
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
  por correo, y luego vive en el Gmail del equipo. Y la lista de «Avísame
  cuando salga» (D15, 2026-10-14): el celular y la fecha del permiso quedan
  en el backend hasta el aviso o hasta que la persona pida borrarlo.

## Lo que tienes que hacer tú

Necesitan un teléfono, una cuenta o estar presente.

- **Probar la lista desde la web** (D15): `WEB_ORIGINS` ya abre
  `https://yavienetech.com` (2026-10-15). Falta mandar un número propio
  desde la web publicada y verlo en `GET /api/admin/lanzamiento`.

- **Probar el buzón** (D14): desde la pestaña Buzón de la APK nueva, mandar un
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
- **Entrar al panel web** en
  `https://occupy-shed-squatter.ngrok-free.dev/panel/` con tu cuenta: ver la
  flota, recargar (tiene que seguir dentro) y salir. Ya está servido por el
  backend vivo (2026-10-08); por ngrok se probó la carga, el aviso de ngrok,
  el login del mismo origen (uno ajeno da 403) y el socket, pero no una
  sesión de verdad: esa la abres tú. Para actualizarlo, el runbook del
  backend, «El panel en el navegador».
- **Las fichas de las tiendas** (T5.7): textos, capturas y video.
- **El video de respaldo del pitch** (T10.4), por si el día falla la red.
- **Mirar el tráfico real un rato** para fijar el umbral de latencia de la
  alerta (T7.1).

## Lo que puedo hacer yo

- **Para el domingo 2026-10-18** (dueño, 2026-10-16, en el iPhone):
  1. La guía, en el paso de la distancia, cuando el pasajero nunca ha
     puesto ni guardado una: queda iluminada toda el área y se puede tocar
     cualquier cosa. Debe iluminar solo la rueda.
  2. El botón que lleva a tu pin no lo deja centrado en el mapa (falta
     restar la hoja y la barra).
  3. En la guía, el paso «toca un bus» debe llevar el mapa al bus más
     cercano y decir que se puede mover el mapa para buscar otro.
  4. Al borrar o seleccionar avisos, la barra de abajo tapa el «Deshacer»
     y otro botón que no se alcanza a ver.

- **La barra de abajo en la web** (2026-10-16, rama `referentes-movil`):
  la app cambió el menú lateral por la barra de cuatro pestañas (Mapa,
  Avisos, Buzón, Info). Las maquetas del pasajero en `YaVieneWeb` (rama
  `referentes-web`) siguen dibujando el ☰; falta espejar la barra con sus
  números comentados, y la hoja del mapa que crece de ella (20 por lado,
  cantos de 32, apoyada sobre su hueco, la barra fundida en ella). Y lo
  del mismo día: fondos blancos con sombra suave en lo blanco de encima
  (`AppShadows.soft`) y el fondo de malla de marca del arranque y de
  Info. Y lo último del día: la malla respira (fuerte en el arranque y la
  bienvenida, suave en Info con «Ya Viene» fijo arriba), la lupa de la
  búsqueda en la punta derecha (el subtítulo se queda) y lo de Avisos, Buzón y Legal
  fundiéndose 16 px bajo su barra (`BordeDesvanecido`). El desliz
  entre pestañas no se espeja: las maquetas no cambian de pantalla.

- **El aviso con la app cerrada, por la ruta** (D13, hallado en A2,
  2026-10-08): la app ya mide la distancia por la ruta (`por_ruta.dart`
  del core), pero el servidor que manda el push de Android
  (`revisarAvisos` en `YaVieneBackend/src/avisos_push.ts`) sigue en línea
  recta. Con la app cerrada, un bus a 400 m en recta y a 3 km por la ruta
  todavía avisa antes de tiempo. Falta portar la medida al backend con sus
  mismas pruebas (la U de 1500 × 400 m del core).

- **La tarjeta del aviso activo con el texto al doble** (hallado el
  2026-10-07, ya estaba en `9d0f3a0`): desde el 2026-10-16 ya no se sale
  de la pantalla —lo que no cabe se desplaza dentro de la tarjeta, que no
  se pliega—, pero en iPhone «Te avisamos a 1,0 km» se sigue partiendo
  palabra por palabra junto a su «Cambiar» y el botón dice «Avisarme
  cuan…». Falta la prueba roja que lo ate y acomodarlo (la píldora debajo
  del texto con letra grande, como en `notifications_screen.dart:813`).

- **Dos specs de Playwright que fallan con 5 hilos** (hallado el
  2026-10-16): `carrusel-lamina.spec.ts` y `contraste.spec.ts` fallan solo
  con la carga en paralelo y pasan con `--workers=1`, con y sin el cambio
  del hero. Falta la causa (tiempos de animación bajo carga) y volverlas
  firmes.

- **«Calculando» en la hoja del bus, casi inalcanzable** (hallado el
  2026-10-16): un bus elegido sin posición cae al estado vacío
  (`eta_bottom_sheet.dart`, `if (bus == null) return _buildEmptyState`),
  así que «Calculando» y «Buscando la posición del bus…» solo salen sin
  ubicación con un aviso del pin anterior y sin ancla. Revisar si se
  quitan (con `inventario-estados.md`) o si falta un estado de verdad.

Ojo con la web: el CSS va en 118,3 de 121 KB (98 %; dueño, 2026-10-16: puede
subir) y la carpeta `dist` en 717,8 de 797. Cualquier cambio de la web se
mide antes de sumarlo.

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
