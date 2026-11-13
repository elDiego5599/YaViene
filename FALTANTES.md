# Lo que falta

Al 2026-11-03, cotejado contra el código. Las ramas de trabajo son
`referentes-movil` (app), `referentes-web` (web) y `prueba` (backend); a
`main` se sube por lotes cuando lo pidas
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
  Lo mismo para la actividad en vivo del aviso (pantalla bloqueada y
  Dynamic Island, 2026-10-19): hoy la pone al día la app mientras corre;
  con la app cerrada se queda quieta y a los 2 minutos dice que no tiene
  datos nuevos. Con la cuenta: pedir el token de la actividad
  (`pushType: .token` en `ios/Runner/ActividadEnVivo.swift`), mandarlo al
  servidor con el aviso y que `revisarAvisos` la ponga al día por APNs
  (tipo `liveactivity`, la clave .p8).
- **La licencia de los puntos de recarga del AMB (D21).** La app ya los
  muestra (1.416 puntos del mapa «Puntos para recargas SIBUS», enlazado
  desde sibusoficial.ambq.gov.co, KML consultado el 2026-11-11, sin
  horarios; cada ficha cita la fuente y la fecha). El AMB no publica una
  licencia de reutilización: hace falta que confirme por escrito que
  podemos mostrarlos, por ejemplo en la misma PQRS de D2. Mientras tanto
  se citan como fuente y no se copia nada de Google Maps.

## Lo que tienes que decidir tú

- **El viaje completo** (plan en `docs/viaje-completo.md`, 2026-11-11):
  ya respondiste sus preguntas y va por fases en la rama `viaje-completo`
  (fase 1, quejas, cerrada el 2026-11-12: formulario del pasajero y
  quejas en Reportes del panel; sigue la fase 3, el planificador). Las
  decisiones D19 a D23 quedan como borradores en ese archivo y pasan a
  `YaVieneBackend/docs/decisiones/` al cerrar su fase.
- **Los motivos de la queja** (D18, 2026-11-11): no paró, iba lleno, mal
  trato, conducción, otra ruta, estado del bus y otro. Salen así en la app,
  el correo y el panel; confírmalos o cámbialos.
- **Puntos de recarga: lo que dejó la conversión (D21).** Quedaron fuera 4
  puntos del KML que no son lugares de recarga fijos (DONDE ABDON y las
  Van n.º 1 a 3) y 34 comparten coordenadas con otro punto, así que se ven
  como uno solo. Dime si se quedan así o si se piden al AMB.
- **El saldo de la tarjeta SIBUS de verdad** (Fase 5 hecha con saldo
  simulado y su etiqueta «Simulación», D22, 2026-11-12). Para el real
  hacen falta tres respuestas: quién da el saldo (un convenio con el AMB o
  el operador del recaudo; no hay API pública), el formato del número de
  la tarjeta (hoy se aceptan de 8 a 20 cifras, provisional) y si se
  enseña en el pitch. La recarga (Fase 6, D23, hecha con pasarela
  simulada, 2026-11-13) pide además el convenio para un proveedor real
  y su regreso por universal link; mientras tanto un iPhone real no
  alcanza la pasarela de `localhost` (`tool/pasarela_simulada.py`) y el
  saldo simulado no sube tras una recarga aprobada.
- **Hora de llegada (D24, abierta).** La regla dice distancia, no minutos.
  La propuesta (sección 3.7 del plan) es seguir sin minutos y, si algún día
  se abre, un rango con datos reales del piloto debajo de la distancia,
  nunca en su lugar. Decides tú.
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
  Y los reportes de búsquedas (D17, 2026-10-25): al elegir una ruta, la
  app manda la ruta y la celda de unos 150 m del punto; el backend guarda
  solo conteos por ruta, hora y celda (sin IP ni equipo), 13 meses, y el
  panel muestra celdas con 5 búsquedas o más. La privacidad ya lo dice
  (versión 7, 2026-10-27, app y web: solo lo ve la empresa dueña de la
  ruta, un trato en el que ganan los dos); falta que el abogado revise ese
  texto. Y las quejas (D18, privacidad versión 8, 2026-11-11): motivo,
  ruta, bus, la hora en punto y, solo si la persona lo activa, la casilla
  de unos 150 m; las lee la empresa de la ruta, sin verificar, 13 meses.
- **Los nombres de cuatro rutas de Coochofal** (auditoría del
  2026-10-29, AUD29-34): con la insignia del código delante, la fila se lee
  C2 Ruta C-2, C4 Ruta C4, C9 Ruta C9 y C18 Ruta C18, con el código dos
  veces y el guion desigual. Son los nombres que diste el 28 (`66bf635`);
  si quieres, van sin el código repetido, como las demás. Y la R-108 no
  existe en ningún momento de la historia: confirmar que el hueco es a
  propósito.

## Lo que tienes que hacer tú

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

- **La privacidad de la web con las quejas** (D18, 2026-11-11): la app
  ya va en la versión 8 (motivo, ruta, bus, hora en punto, la casilla de
  150 m solo con el interruptor, 13 meses para la empresa de la ruta).
  `privacidad.html` y `tests/coherencia.test.ts` de `YaVieneWeb` siguen en
  la 7: la web está en `referentes-web` con un cambio sin commitear que no
  es mío, así que se espeja cuando se libere.

- **Golden «hoja sin ubicación»** (2026-11-06): `eta_sheet_golden_test`
  falla por 0,35 % (1.139 px) desde antes del cambio de la cámara. Ver el
  diff en `test/golden/failures` y entender por qué antes de regenerar.

- **Búsquedas de ejemplo de Coochofal en Reportes** (2026-10-28): la
  siembra de `busquedas_demo.ts` solo cubre Sobusa y Coolitoral. Espera
  a que se cierre el cambio que otra sesión dejó a medias en ese archivo.

- **Señal perdida con gracia** (dueño, 2026-10-19, punto 10): sin datos
  de un bus, «último dato hace 20 s», el bus atenuado y una carga
  elegante. Los puntos 4, 6 y 7 ya están (giro con resorte, cámara al
  bus tocado, doble toque al sonar); la estela se quitó (dueño,
  2026-10-26).

- **La barra de abajo en la web** (2026-10-16, rama `referentes-movil`):
  la app cambió el menú lateral por la barra de cuatro pestañas (Mapa,
  Avisos, Buzón, Info). Las maquetas del pasajero en `YaVieneWeb` (rama
  `referentes-web`) siguen dibujando el ☰; falta espejar la barra con sus
  números comentados, y la hoja del mapa que crece de ella (20 por lado,
  cantos de 32, apoyada sobre su hueco, la barra fundida en ella). Y lo
  del mismo día: fondos blancos con sombra suave en lo blanco de encima
  (`AppShadows.soft`). Y lo
  último del día: la lupa de la
  búsqueda en la punta derecha (el subtítulo se queda) y Avisos, Buzón,
  Info y Legal pasando bajo una barra de vidrio como el nav de la web
  (2026-10-18, `barra_vidrio.dart`, como iOS 26 con WhatsApp de
  referencia: sin lámina; en reposo no hay nada y al bajar sale de a
  poco, al paso del dedo en 40 px, y se va igual al subir (2026-10-19), un
  velo blanco que se desvanece hasta cero al pie de la barra sobre un
  desenfoque progresivo (8·f², de 8 arriba a casi 0 al pie, sin la raya
  recta de antes, en 16 capas que se suman), el título con
  halo y los botones en píldoras de vidrio de 48 con desenfoque 10 y
  saturación 1,8; opaca con más contraste). El desliz
  entre pestañas no se espeja: las maquetas no cambian de pantalla. Y el
  arranque nuevo (2026-10-18): la Ventana al Mundo, la cayena de cinco
  pétalos sueltos (112 de lado) y un bus sin empresa, verde, con el
  letrero de Barranquilla y las franjas de la bandera (`escena_arranque.dart`;
  el nombre de Sobusa hacía creer que la app era solo de ellos,
  `bus_arranque_test.dart`,
  1,7 s con medio segundo de marca, sin adornos), con la torre sobre su
  isla de pasto con canto, briznas y cuatro arbustos floridos, y una calle
  de frente bajo el bus, con bordillos y raya blanca (`PintorSuelo`), sobre el
  blanco con trama de puntos (`FondoTexturizado`, 2026-10-19; el matizado
  azul y verde se fue), que es también el fondo de la bienvenida, Avisos,
  Buzón e Info, con el nombre en tinta y la bajada en
  `textBody` (la malla oscura se fue);
  y en Avisos, arriba, la nota «Gestiona, borra o desactiva tus avisos
  aquí.» con su ícono, y dejar presionado un aviso lo selecciona; y en Info dibujos chicos de
  Barranquilla regados sin orden solo arriba, detrás del logo, que se
  apagan antes de la tarjeta (franja de 200 bajo el borde seguro, enteros
  los primeros 80; cayena, sol, palmera, marimonda, la torre del arranque
  y, pocos y separados, los buses de Sobusa y Coolitoral, las empresas de
  la app; de 44 a 60, a 70 entre centros, sin dos iguales juntos, al 72 %
  y sin relleno en los huecos; `fondo_ilustrado.dart`; la torre adelgaza
  sus juntas con el tamaño) sobre blanco, con la letra en píldoras
  blancas; y la tarjeta de la ruta activa con su chevrón lleva al mapa
  (sin ruta, abre el selector), se hunde al tocarla y vibra. Y lo que lee el pasajero va sin «», rayas
  ni -- (2026-10-18; `textos_sin_signos_test.dart`, y lo legal de la web
  en `coherencia.test.ts`): el rango de la rueda dice «0,7 a 1,2 km». Y las áreas iluminadas de la guía
  (2026-10-18): el mapa libre entre la cabecera y la hoja, la píldora
  entera con su forma, el botón del aviso y «Ver buses en vivo» como píldoras, en las listas solo
  de la primera fila a la última, y la carta encima de la hoja si cabe. La
  maqueta del trío del hero (`.tinta-hero` en `phone-simulator.css`) sigue
  con la marca de 84 sobre tinta. Ojo con el CSS
  al 98 %. Y el lote siguiente del mismo día: títulos de sección como Salud
  del iPhone (`titulo_seccion.dart`, 22 en negrita, 28 arriba y 10 abajo)
  en Avisos, Info (Ayuda, Información) y Buzón (Tipo de mensaje, Tu
  mensaje); Seleccionar y Cancelar en píldoras compactas (cara de 36,
  toque de 48) a ras de las tarjetas; las opciones del buzón con su color
  sin elegir (problema en coral, sugerencia en ámbar), y los créditos del
  mapa dentro de Acerca de, sin la píldora del pie de Info.
  Y del 2026-10-19: con un bus tocado, la píldora de tu punto y de
  cuántos buses hay cerca se va (si la maqueta del mapa la dibuja con un
  bus elegido). Y luego, el mismo día: Avisos y Buzón en blanco, con
  tarjetas planas, sin sombra, y su filo en el color de la app (`filo`,
  #D0D4DC); una raya del mismo filo parte cada tarjeta de Avisos, y la
  del mensaje del buzón va sin raya, con la nota de privacidad fuera,
  debajo; y la ficha de la ruta del aviso en el color de
  su empresa del selector (`colorEmpresa`), si la maqueta de Avisos la
  dibuja.

- **El aviso con la app cerrada, por la ruta** (D13, hallado en A2,
  2026-10-08): la app ya mide la distancia por la ruta (`por_ruta.dart`
  del core), pero el servidor que manda el push de Android
  (`revisarAvisos` en `YaVieneBackend/src/data/avisos_push.ts`) sigue en línea
  recta. Con la app cerrada, un bus a 400 m en recta y a 3 km por la ruta
  todavía avisa antes de tiempo. Falta portar la medida al backend con sus
  mismas pruebas (la U de 1500 × 400 m del core; del 2026-11-04, se
  espera en el punto de la ruta más cerca del pin, a cualquier distancia,
  y se cuenta solo la ruta hasta ahí (del 2026-11-05: el pin marca dónde
  se toma el bus, no se suma la caminada), con el otro carril de una
  calle de ida y vuelta si pasa a 30 m o menos de ese punto: la ventana de
  300 m hacía saltar la C16 de 5,8 a 19,3 km al correr el pin 50 m; y
  del 2026-10-19, la distancia al paso más cerca, venga o ya haya pasado,
  sin contar nunca la vuelta entera: con el bus 80 m pasado se sumaba la
  vuelta y salían 20 km; y desde cada paso de la ruta por donde está el
  bus, no solo su carril: dos buses lado a lado, de ida y de vuelta,
  daban 10 y 29 km).

- **`alongroute` con la regla del 2026-10-19**: portada en TS y Dart con
  sus vectores, README y diseño (`83a7571`, solo local). Falta que el
  dueño diga si se sube a su `main`, que lanza su CI.

- **La tarjeta del aviso activo con el texto al doble** (hallado el
  2026-10-07, ya estaba en `9d0f3a0`): desde el 2026-10-16 ya no se sale
  de la pantalla —lo que no cabe se desplaza dentro de la tarjeta, que no
  se pliega—, pero en iPhone «Te avisamos a 1,0 km» se sigue partiendo
  palabra por palabra junto a su «Cambiar» y el botón dice «Avisarme
  cuan…». Falta la prueba roja que lo ate y acomodarlo (la píldora debajo
  del texto con letra grande, como en `notifications_screen.dart:813`).

- **Un spec de Playwright que falla con 5 hilos** (hallado el
  2026-10-16): `contraste.spec.ts` falla solo con la carga en paralelo y
  pasa con `--workers=1`. Falta la causa y volverlo firme
  (`carrusel-lamina.spec.ts` ya quedó firme en `6ec85f6`).

- **«Calculando» en la hoja del bus, casi inalcanzable** (hallado el
  2026-10-16): un bus elegido sin posición cae al estado vacío
  (`eta_bottom_sheet.dart`, `if (bus == null) return _buildEmptyState`),
  así que «Calculando» y «Buscando la posición del bus…» solo salen sin
  ubicación con un aviso del pin anterior y sin ancla. Revisar si se
  quitan (con `inventario-estados.md`) o si falta un estado de verdad.

- **Endurecer el backend, lo que queda** (AUD29-06, 07, 08 y 17; los
  demás del 05 al 18 ya están en `main` o en `prueba`): el login sin tope
  por cuenta entre IPs (los dos limitadores llevan la IP); el POST de
  búsquedas, anónimo, que puede inflar Reportes; el alta de admin sin 404
  si la empresa no existe (hoy la crea con `ensureEmpresa`) ni tope al
  largo del usuario, y el gzip del panel web en cada petición
  (`panel_web.ts:117`).

- **La app, seguridad y lógica, lo que queda** (AUD29-20 a 29, salvo lo
  del árbol de arriba): `dataSync` sin `onTimeout` en Android 15
  (plausible, va con T5.5); la web con una sola URL, sin respaldo (Fly ya
  existe, así que ya se puede); el comentario viejo y el `dispose`
  incompleto en `proximity_alerts_provider.dart`; `_ultimo` de
  `por_ruta.dart`, que solo se poda en un camino; el doble reintento del
  socket (`realtime_service.dart:169`); seis archivos de más de 1.200
  líneas, a partir cuando se toquen, y los conteos de pruebas de
  `CLAUDE.md`, del 8 de octubre.

- **Retoques de diseño, lo que queda** (AUD29-31 a 42, salvo lo del árbol
  de arriba): el monograma CO repetido en Coochofal y Coolitoral; el ícono
  genérico de empresa (`Icons.business_outlined`) en vez del monograma en
  su color; la píldora de estado más ancha que la cabecera; y en Info, el
  tracking de la tarjeta de la ruta activa (`letterSpacing: 1.2`), sus
  terminales centradas y el chevrón que solo lleva ella.

Ojo con la web: el CSS va en 118,5 de 121 KB (98 %; dueño, 2026-10-16: puede
subir) y la carpeta `dist` en 719,2 de 797. Cualquier cambio de la web se
mide antes de sumarlo.

## El día antes y el día del pitch

1. **El respaldo en Fly ya está arriba** (2026-11-02, la máquina siempre
   prendida): el día anterior, cargarle los datos al día (T2.4).
   El 2026-11-06 no contestaba (`/api/ready` sin respuesta en 15 s): el
   pasajero y el panel de ese día se compilaron con
   `BACKEND_URL_FALLBACK=` vacío, para no esperar 20 s a un respaldo
   muerto ni decir «respaldo» con datos. Con Fly de vuelta, recompilar sin
   ese define.
2. **Con Fly arriba**: matar ngrok tres veces y cronometrar que el pasajero
   y el panel se pasan solos al respaldo en 55 s o menos (simulacro a de
   T10.5), y que al revivir ngrok vuelven solos a él en 30 s o menos
   (`BackendUrl.vueltaCada`).
3. **El repaso del día anterior, el día mismo y lo de después** (T10.6,
   T10.7 y T10.8). `check-demo.sh` revisa todo lo que se puede revisar solo.

## Después

- **La ocupación de verdad.** La tarjeta del bus dice «Ocupación aprox.»
  con un porcentaje que sube y baja por tramos de la ruta, distinto en cada
  bus y más alto en hora pico, pero es de ejemplo (`ocupacionSimulada` en
  el core, 2026-10-27). Cuando haya cámaras en los buses
  (`YaVieneBackend/prototipo-aforo`), el conteo llega del servidor y
  reemplaza esa función en `ocupacionEnRuta`
  (`app_pasajero/.../widgets/ocupacion_bus.dart`).
- **Planificador de viaje, como Q'Ruta (propuesta del dueño,
  2026-11-04; fase 2 del piloto, no antes).** El pasajero dice dónde está y
  a dónde va, se le arma la ruta, un botón lo lleva al mapa con la empresa y
  la ruta puestas para activar el aviso. Con dos o más buses, el sistema
  detecta que ya está cerca del punto donde debe bajarse, o el pasajero lo
  avanza solo, y otro botón pone solo la siguiente empresa y ruta hasta
  llegar. Pesa semanas, no días. Lo que exige:
  1. **Buscar sitios**: hecho el buscador (D25: índice local de OSM y POT,
     `BuscaLugar` en el core). Falta conectarlo al planificador y al mapa:
     elegir en el mapa, «Tu ubicación» y la cámara hacia lo elegido.
  2. **Armar la ruta de A a B**: qué ruta pasa cerca del origen, cuál deja
     cerca del destino, trasbordos y caminata entre buses. Es un buscador
     de rutas completo.
  3. **Calidad de los recorridos**: si falta o está mal el de una ruta, el
     plan sale mal (Coochofal viene de KMZ).
  4. **Guía de varios buses**: choca con la regla 14 del producto (se
     sigue un solo bus a la vez, la guía no se reanuda sola); habría que
     cambiarla por decisión del dueño.
  Para el pitch va solo como «lo que sigue» (lámina del piloto y guion), sin
  prometer fechas. El plan ya está en `docs/viaje-completo.md` (fase 3,
  2026-11-11); si se adelanta lo decides tú (pregunta 7 de ese plan).


Una **auditoría con ojos frescos**, en una sesión nueva sin este contexto, con
el prompt de `archivo/prompt-revision.md` (en la raíz del workspace). Si
encuentra algo grave, entra aquí antes de dar el plan por cerrado.
