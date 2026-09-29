# Auditoría de solo lectura — app_pasajero, app_control, ya_viene_core, ya_viene_pruebas

Fecha: 2026-09-29. Rama base: `main` en `bfcc8d2`. No se cambió código: este
documento es lo único que se agrega.

## Alcance y cómo se hizo

- **Paquetes**: `app_pasajero`, `app_control` y `ya_viene_core` en `main`.
  `ya_viene_pruebas` **no existe en `main`**: vive solo en la rama
  `claude/youthful-ramanujan-13putx` (`58be675`, sin fusionar) y se auditó
  desde ahí.
- **No se leyeron** `key.properties`, `google-services.json` ni
  `GoogleService-Info.plist`.
- **Máquina**: Linux, Flutter 3.44.4 (la de la CI). Las pruebas de oro solo
  valen en el Mac y **no se cuentan como fallo**.
- **Reproducciones**: 9 pruebas escritas **fuera del repo**, en una copia
  aparte (`test/_auditoria/`). Están en el apéndice A, listas para pegar. Cada
  una **pasa** cuando el defecto está presente: comprueban el comportamiento
  malo, no el bueno.

### Línea base medida

| Paquete | `flutter analyze --fatal-infos lib test` | `flutter test` en Linux |
|---|---|---|
| ya_viene_core | 0 avisos | 71 / 71 |
| app_pasajero | 0 avisos | 367 pasan, 35 fallan: 34 de oro (se descartan) y 1 de contraste que falla solo en Linux (H25) |
| app_control | 0 avisos | 238 pasan, 1 saltada, 2 fallan: contraste solo en Linux (H25) |
| ya_viene_pruebas (rama) | 0 avisos | 7 / 7 |

Los totales cuadran con `CLAUDE.md`: pasajero 402 y panel 240 + 1.

## Resumen

| Gravedad | Cuántos | Qué quiere decir aquí |
|---|---|---|
| **P0** | 0 | Caída, pérdida de datos o brecha que se explota ya |
| **P1** | 3 | Rompe la función principal (el aviso) o engaña al usuario en casos reales |
| **P2** | 4 | Defecto real con impacto acotado, o un riesgo de seguridad que hay que cerrar |
| **P3** | 21 | Higiene: código muerto, pruebas débiles, configuración, detalles |
| **Total** | **28** | |

### Los 5 más importantes

1. **H1 (P1)**: el servicio en primer plano de Android arranca al abrir el
   mapa aunque no haya ningún aviso, nunca se detiene y sobrevive a cerrar la
   app desde recientes, con una notificación fija que dice «Seguimiento de buses».
2. **H2 (P1)**: con las notificaciones apagadas, `notifyBusNear` devuelve
   `true`. El aviso queda como «enviado» y se desarma sin que el teléfono
   haya mostrado nada. Reproducido.
3. **H3 (P1)**: en iPhone la guía y la hoja dicen «Puedes cambiar de
   aplicación: Ya Viene seguirá pendiente del bus», y en iOS eso no pasa.
4. **H4 (P2)**: la contraseña recordada del administrador se carga en el
   campo, y el botón del ojo la muestra en claro a cualquiera que se siente
   frente al equipo después de cerrar sesión. Reproducido.
5. **H5 (P2)**: `MapScreen.build` vuelve a correr con cada foto de
   posiciones (cada 200 ms con buses moviéndose) y con cada lectura del GPS.
   Reconstruye la pantalla entera por una etiqueta de accesibilidad.
   Reproducido.

---

## P1

### H1 · El seguimiento en segundo plano de Android corre sin avisos y no muere

- **Dónde**: `app_pasajero/lib/features/map/presentation/screens/map_screen.dart:106`
  (`BackgroundKeepAlive.start()` sin condición);
  `app_pasajero/lib/services/background_keep_alive.dart:21-51`;
  `app_pasajero/lib/core/providers/app_state.dart:21`, el único `stop()`,
  que solo corre en el splash de un arranque en frío;
  `app_pasajero/android/app/src/main/AndroidManifest.xml:45`
  (`stopWithTask="false"`).
- **Qué pasa**:
  - Al entrar al mapa arranca un servicio en primer plano de tipo `dataSync`
    aunque la persona no haya armado ningún aviso.
  - Mientras el proceso vive, el socket sigue recibiendo posiciones con la
    app en el fondo.
  - El plugin (`flutter_background_service_android` 6.3.1) se vuelve a
    lanzar solo: `BackgroundService.java:252` (`onTaskRemoved` →
    `WatchdogReceiver.enqueue`) y `:106` (`onDestroy` → reprograma, salvo
    un `stopService` explícito). Si la persona desliza la app fuera de
    recientes, el motor de Flutter con el socket y los avisos muere, pero el
    servicio y su notificación fija «Seguimiento de buses en segundo plano»
    siguen, y el perro guardián los revive.
  - Riesgo sin probar en un dispositivo: con `targetSdk` 36, Android 15
    limita `dataSync` a 6 h por día y llama a `Service.onTimeout`. El plugin
    no lo implementa, y un servicio que no se detiene a tiempo tumba el
    proceso.
- **Cómo comprobarlo**: en un Android, abre la app y no armes ningún aviso.
  Sal: aparece la notificación fija. Desliza la app fuera de recientes: la
  notificación sigue. `adb shell dumpsys activity services id.flutter` muestra
  el servicio vivo.
- **Arreglo**:
  - Encender y apagar el servicio según los avisos: un
    `ref.listen(activeAlertsProvider, …)` que llame a `start()` cuando la
    lista pasa a tener algo y a `stop()` cuando queda vacía.
  - Cambiar a `stopWithTask="true"` en el `<service>` que ya se
    sobrescribe. El texto de la app ya dice «no cierres Ya Viene del todo».
  - Llamar a `stop()` también en `AppLifecycleState.detached`.
  - Mientras el plugin no implemente `onTimeout`, poner un tope propio al
    servicio, por ejemplo la `vidaDeUnAviso` de 3 h.

### H2 · Un aviso sin permiso de notificaciones se da por mostrado

- **Dónde**:
  - `app_pasajero/lib/core/services/bus_notification_service.dart:91-126`:
    `show` y luego `return true`.
  - Consecuencia en
    `app_pasajero/lib/features/notifications/presentation/providers/proximity_alerts_provider.dart:355-368`:
    `markSent`, `deactivateAlert` y `disarmAlert`.
- **Qué pasa**:
  - El comentario de la función dice que se arregló «el permiso revocado
    desde ajustes». No es así: ni Android (`NotificationManagerCompat.notify`)
    ni iOS lanzan un error cuando no hay permiso o el canal «Alertas de buses»
    está apagado. El sistema descarta la notificación sin decir nada.
  - `show` termina bien y la función devuelve `true`. El historial marca el
    aviso como enviado y lo desarma.
  - `restore()` (`:101`) vuelve a armar avisos al abrir la app sin mirar si
    todavía hay permiso.
- **Cómo comprobarlo**: la prueba A.1 simula el canal nativo con
  `areNotificationsEnabled → false`. `notifyBusNear` devuelve `true` y llama a
  `show`. En un teléfono: arma un aviso, apaga las notificaciones de la app en
  Ajustes y espera al bus. No suena nada y el aviso aparece como «enviado».
- **Arreglo**:
  - En `notifyBusNear`, comprobar `areNotificationsEnabled()` antes de
    `show`. En Android, también `getNotificationChannels()` para ver que
    `bus_alerts` no esté en `Importance.none`. Si no hay permiso, devolver
    `false`: el aviso sigue armado y el barrido reintenta.
  - En `restore()` y en cada `resumed`, si no hay permiso, mostrarlo en la
    hoja: «Tus avisos están apagados en Ajustes».

### H3 · En iPhone la app promete avisos con la app en el fondo

- **Dónde**:
  `app_pasajero/lib/features/map/presentation/providers/map_guide_copy.dart:150-157`
  (paso «Sigue con lo tuyo»: «Ya Viene seguirá pendiente del bus») y
  `app_pasajero/lib/features/map/presentation/widgets/eta_bottom_sheet.dart:807`
  («Puedes cambiar de aplicación; no cierres Ya Viene del todo»). Los dos se
  muestran en todas las plataformas.
- **Qué pasa**: iOS no tiene `UIBackgroundModes` (ver `Info.plist`) ni un
  servicio equivalente (`BackgroundKeepAlive` solo actúa en Android). Al
  cambiar de app, iOS suspende el proceso en segundos y el aviso no suena. La
  pantalla de Notificaciones (`notifications_screen.dart:87-88`) y la política
  de privacidad (`legal_docs.dart:88-93`) dicen lo contrario que la guía: «en
  iPhone el aviso solo suena con la app abierta». La persona sigue la guía,
  cambia de app y pierde el bus.
- **Cómo comprobarlo**: en un iPhone, arma un aviso, pasa a otra app y espera
  a que el bus entre en 1 km. No hay notificación.
- **Arreglo**: textos según la plataforma. En iOS: «Deja Ya Viene abierta y
  con la pantalla encendida para que el aviso suene». A la larga, si el aviso
  en el fondo importa en iOS, hacen falta notificaciones push del servidor.
  Es una decisión del dueño.

## P2

### H4 · La contraseña recordada del panel se lee en claro sin sesión

- **Dónde**:
  - `app_control/lib/features/auth/presentation/screens/login_screen.dart:76-89`
    carga usuario y clave en los campos al abrir.
  - `:338-352`: el ojo «Mostrar contraseña».
  - `app_control/lib/features/auth/presentation/providers/auth_providers.dart:62-63, 179-186`:
    la clave se guarda tal cual en el llavero o almacén cifrado.
- **Qué pasa**: el almacén está bien protegido, pero la pantalla deshace esa
  protección. En un equipo compartido de oficina, después de «Salir» o de una
  sesión vencida, la pantalla de ingreso abre con la clave del administrador
  (la de toda la flota) ya puesta. Un clic en el ojo la muestra, y quien la
  lea puede usarla desde cualquier otro equipo.
- **Cómo comprobarlo**: prueba A.6. Con `recordar_clave` en el almacén, un
  toque en «Mostrar contraseña» deja `obscureText == false` y el campo con la
  clave.
- **Arreglo** (de más a menos seguro):
  1. Recordar solo el usuario.
  2. Recordar la sesión con un token de larga vida revocable, no la clave.
  3. Si se queda la clave: no ponerla en el `TextEditingController`.
     Mostrar «Contraseña recordada», enviarla desde el almacén al pulsar
     INGRESAR y desactivar el ojo mientras venga del almacén.

### H5 · Cada foto de posiciones reconstruye la pantalla entera del mapa

- **Dónde**:
  `app_pasajero/lib/features/map/presentation/screens/map_screen.dart:317-338`.
  `_accionesDeBuses` hace `ref.watch(busPositionsSourceProvider(…))` y
  `ref.watch(userLocationProvider)` dentro de `build` (`:386`).
- **Qué pasa**: el stream emite como mucho cada 200 ms (`bus_stream.dart:25`),
  y el GPS con cada movimiento de 8 m. Cada emisión reconstruye el `Scaffold`
  completo: `MapWidget` (y su `didUpdateWidget`), la cabecera, la hoja, la
  guía y un `Semantics` que envuelve todo el mapa. Con el lector de pantalla
  activo, además, cada vez se manda al sistema un árbol de semántica nuevo. Lo
  único que necesita esos datos es la etiqueta y las acciones del mapa.
- **Cómo comprobarlo**: prueba A.3. Tras una foto de buses, el `MapWidget` del
  árbol es otra instancia. En el cuadro de control, sin eventos, es la misma.
- **Arreglo**: sacar el `Semantics` y sus acciones a un `ConsumerWidget`
  pequeño que reciba `MapWidget` como `child` ya construido. Así solo se
  reconstruye el envoltorio y `MapWidget` conserva su identidad. Además, que
  mire `busPositionsSourceProvider(...).select(...)` con la lista de
  `(busId, distancia redondeada, fantasma)`, para no despertarse por cada
  metro.

### H6 · El GPS que falla borra el pin recién puesto, y al volver del fondo la ubicación desaparece

- **Dónde**:
  `app_pasajero/lib/features/map/presentation/providers/user_location_provider.dart:227-253`
  (`_locate`: `:228` pone `locating` sin lat/lon; `:231` y `:250-251` pasan a
  `gpsFailed` sin mirar si el usuario puso un pin en el camino) y `:215-225`
  (`resumeGpsIfNeeded` no restaura el pin guardado, a diferencia de
  `initialize` y `useGps`).
- **Qué pasa**:
  - `_locate` sí respeta el pin cuando el GPS **contesta** (`:242`), pero no
    cuando **falla** (el `timeLimit` es de 15 s).
  - Al volver del fondo con el flujo del GPS cortado, la ubicación se borra
    hasta 15 s (modo `locating`). Mientras tanto, los avisos armados con GPS
    (sin ancla) no miden: `proximity_alerts_provider.dart:331-332`.
  - Si en esos 15 s la persona toca el mapa y el GPS se agota, su pin
    desaparece de la pantalla (queda `gpsFailed`) aunque esté guardado en
    disco.
- **Cómo comprobarlo**: prueba A.2, con un `GeolocatorPlatform` falso: GPS,
  corte del flujo, `resumeGpsIfNeeded`, pin manual y *timeout*. Termina en
  `gpsFailed` y sin posición.
- **Arreglo**:
  - En los dos `gpsFailed` de `_locate`: `if (state.mode == manual) return;`.
  - Al reanudar, mantener la última posición (`mode: gps` con su `updatedAt`
    viejo) en lugar de vaciarla.
  - Que `resumeGpsIfNeeded` también llame a `_restoreSavedPin()` si termina
    en `gpsFailed`.

### H7 · El panel revierte fotos enteras al fallar un cambio de visibilidad

- **Dónde**:
  `app_control/lib/features/fleet/presentation/providers/fleet_providers.dart:591-610`
  (`setAllVisibility`: `buses: previous`) y `:565-589` (`toggleVisibility`:
  `busId: previous`).
- **Qué pasa**: para deshacer el cambio optimista se restaura la foto
  **completa** tomada antes de la petición (8 s de *timeout*). Se pierde todo
  lo que llegó mientras tanto: buses creados o borrados, posiciones más
  nuevas y cambios de otro panel. En `toggleVisibility` el bus vuelve a una
  posición vieja, justo lo que T2.5 evita en el resto del notifier.
- **Cómo comprobarlo**: prueba A.7. Con «ocultar todos» en vuelo se crea un
  bus. Al fallar, el bus desaparece del panel aunque el backend lo tiene.
- **Arreglo**: revertir solo el campo `visible` de los buses que siguen en el
  estado actual (`state.buses[id]?.copyWith(visible: !visible)`), no la foto
  anterior.

## P3

### Lógica, estado y ciclo de vida

- **H8 · «Instance of 'SessionExpiredException'» en el diálogo de rutas.**
  `app_control/lib/features/fleet/presentation/widgets/route_dialog.dart:52-58`
  hace `e.toString().replaceFirst('Exception: ', '')` sobre cualquier
  `Exception`, y `SessionExpiredException` no tiene `toString`. Se comprueba
  con la prueba A.8. Arreglo: tratar `SessionExpiredException` aparte (la
  ventana de sesión vencida ya la maneja el tablero) y lanzar una excepción
  con `message` en `addRoute` en lugar de `Exception(message)`.
- **H9 · Registro de acciones de accesibilidad sin tope.**
  `map_screen.dart:332-336` crea un `CustomSemanticsAction` por bus cuya
  etiqueta lleva la distancia al metro (`bus_semantics.dart:37-43`).
  `CustomSemanticsAction.getIdentifier` guarda cada etiqueta nueva en un mapa
  estático que nunca se libera. Con el lector de pantalla activo, un bus que se
  acerca 1 km deja unas 90 entradas. La prueba A.4 lo mide. Arreglo:
  redondear a 50 o 100 m en la etiqueta (la tarjeta ya da la cifra fina), o
  mover la distancia a la etiqueta del nodo y no a la acción.
- **H10 · `PulsingDot` ignora «Reducir movimiento».**
  `ya_viene_core/lib/shared/widgets/pulsing_dot.dart:36-39` hace `repeat()`
  sin mirar `AppMotion.reducido`. Los demás latidos de la app sí lo miran
  (`indicador_carga.dart:64`, `latido.dart:53`, `map_widget.dart`). Se
  comprueba con la prueba A.9. Arreglo: el mismo patrón de `IndicadorCarga`
  en `didChangeDependencies`.
- **H11 · La pantalla de Notificaciones mide desde otro punto que el aviso.**
  `app_pasajero/lib/features/notifications/presentation/screens/notifications_screen.dart:21-27, 231-240`:
  - Mide desde la ubicación en vivo, no desde el ancla del aviso
    (`proximityAlertsProvider.notifier.anchorFor`). La hoja de abajo sí usa
    el ancla.
  - Solo lee posiciones de la ruta elegida: un aviso de otra ruta sale sin
    distancia.
  - La pantalla entera se reconstruye con cada foto.

  Arreglo: por cada entrada, `busPositionsSourceProvider(entry.routeId)` y
  el ancla del aviso, en un `Consumer` por fila.
- **H12 · El panel puede tardar ~31 s en pintar algo.**
  `app_control/lib/main.dart:33-72`: `runApp` espera al `BackendResolver`
  (3 s + 20 s si el principal no contesta) y a `restoreSession`, que valida el
  token con Dio (8 s). La ventana queda en blanco todo ese rato. El pasajero
  ya lo resolvió con `_ArranqueTemprano`. Arreglo: el mismo patrón, `runApp`
  inmediato con una pantalla de carga.
- **H13 · Expulsión del socket y 401 no cortan lo mismo.** El manejador de
  `sessionKickedStream` (`fleet_providers.dart:213-226`) no cancela `_resync`
  ni `_recarga`, a diferencia de `_onSessionExpired` (`:172-189`). El reloj de
  60 s vuelve a llamar al REST con el token muerto hasta que un 401 lo corta.
  Arreglo: una sola función `_cortarSesion()` para las dos rutas.

### Seguridad y configuración

- **H14 · Texto en claro permitido en release.**
  `app_pasajero/android/app/src/main/res/xml/network_security_config.xml:13-16`
  deja HTTP hacia `localhost` y `10.0.2.2` también en release. Ya está
  corregido en `6ea563c` (rama sin fusionar), que lo mueve a `src/debug`. Falta
  fusionarlo.
- **H15 · El pasajero no exige https en release.** `app_pasajero/lib/config.dart:9-20`
  acepta cualquier `BACKEND_URL`. El panel sí lo exige (`AppConfig.esSegura`).
  En Android la red lo bloquea igual y el fallo es mudo. Arreglo: el mismo
  `esSegura` en el arranque del pasajero, con su `StateError` explicativo.
- **H16 · El bloqueo vertical no vale en iPad.**
  `app_pasajero/ios/Runner/Info.plist:58-70` declara orientaciones apaisadas
  para iPhone y todas para iPad, y el proyecto compila con
  `TARGETED_DEVICE_FAMILY = "1,2"` (`project.pbxproj:475`). En iPad con
  multitarea, `setPreferredOrientations` se ignora y la app gira. Contradice
  la regla 6. Arreglo: solo `Portrait` en la clave de iPhone y
  `TARGETED_DEVICE_FAMILY = 1`, o `UIRequiresFullScreen = YES`.
- **H17 · Registros en release.** `debugPrint` escribe también en release
  (logcat o consola del sistema). El panel registra placa, ruta e interno de
  cada alta o edición (`fleet_providers.dart:498-671`) y el `toString` de
  `DioException`, que trae la URL. El pasajero deja `debugLogDiagnostics: true`
  en `core/router/app_router.dart:35`. No sale ninguna clave ni token.
  Arreglo: envolver en `if (kDebugMode)` o usar un registrador que no haga
  nada en release.
- **H18 · Datos de ubicación en texto plano y en la copia de iCloud.** Es un
  riesgo aceptado y documentado en `core/prefs_keys.dart`. Se incluye porque
  la auditoría pide decir qué se guarda y cómo:
  - `user_location_provider.dart:54-55, 300-304`: el pin de espera, con
    precisión completa.
  - `alert_history_provider.dart:53-61`: el historial, con ruta, hora y
    ancla de cada aviso.

  Todo va en `SharedPreferences`. Android lo excluye de copias
  (`backup_rules.xml`, `data_extraction_rules.xml`); iOS lo sube a iCloud. Los
  tokens y claves del panel sí van en el llavero o almacén cifrado
  (`auth_providers.dart:51-53`). Arreglo barato: guardar el ancla redondeada a
  4 decimales (~11 m). El radio del aviso es de 1 km.

### Pruebas débiles

- **H19 · Ninguna prueba monta `MapScreen`.** Es la pantalla que conecta el
  socket, restaura avisos, arranca el barrido y el servicio en el fondo
  (`map_screen.dart:99-107`). Por eso H1 y H5 pasaron sin ruido. La prueba
  A.3 demuestra que se puede montar con un repositorio falso. Arreglo: una
  prueba de orquestación con esos *fakes*.
- **H20 · El camino real de la notificación no se prueba.** Todas las pruebas
  de avisos inyectan `notify:` (`alert_history_test.dart:51`,
  `alert_toggle_provider_test.dart:50`, `app_router_test.dart:25`), y ninguna
  ejercita `BusNotificationService`. Por eso el «devuelve false si no se
  mostró» es verdad en las pruebas y mentira en el teléfono (H2). Arreglo:
  pruebas de `BusNotificationService` con el canal simulado, como en A.1.
- **H21 · `UserLocationNotifier` solo se prueba sin GPS.**
  `app_pasajero/test/user_location_test.dart` cubre permiso negado y pin
  guardado. Las ramas con GPS (`_locate`, el flujo, `resumeGpsIfNeeded`)
  no tienen prueba, y ahí está H6. La prueba A.2 muestra cómo simular
  `GeolocatorPlatform`.
- **H22 · Una prueba depende del orden de las demás.**
  `app_pasajero/test/coherencia_textos_test.dart:346` («cada escena de la
  lista se montó») lee un `Set` que llenan las pruebas anteriores. Falla sola
  con `--plain-name "cada escena de la lista"` (`Actual: Set:[]`) y con
  `--test-randomize-ordering-seed=7`. Arreglo: montar todas las escenas en un
  `setUpAll`, o comprobar la lista contra la tabla de forma estática.
- **H23 · La guía de contraste no mide texto con otra etiqueta.**
  `GuiaContraste` (`ya_viene_pruebas/lib/contraste.dart:96-99`, igual que
  `textContrastGuideline` de Flutter) busca `find.text(label)`. Un
  `Semantics(label: …)` sobre un `ExcludeSemantics(Text(…))`, o un
  `MergeSemantics`, no encuentra ningún `Text` y **pasa sin medir nada**. La
  app usa ese patrón 18 veces. La prueba A.5 lo muestra: un gris a 1,2:1 pasa
  con otra etiqueta y falla sin ella. Arreglo: en la guía, cuando
  `find.text` no encuentra nada, medir los `RenderParagraph` que caen dentro
  de `nodo.rect`, o fallar para que la escena se pruebe aparte.
- **H24 · `ya_viene_pruebas` no prueba su propia tesis.**
  - `test/contraste_test.dart:176` («fotografía a tres píxeles por punto»)
    compara una constante consigo misma.
  - Todas sus pruebas dibujan con Ahem, sin suavizado. Nada en el paquete
    comprueba que medir a 3× arregla el suavizado de FreeType, que es su
    razón de existir; eso solo lo muestran las pruebas de las apps.

  Arreglo: una prueba con `PlusJakartaSans` cargada que falle a 1× y pase a
  3× con el mismo color.
- **H25 · Tres pruebas de contraste fallan en Linux sobre `main`.**
  `accesibilidad_pasajero_test.dart` («los dos documentos legales») y dos de
  `accesibilidad_panel_test.dart` («el dashboard…», «el login…»). Miden
  #858EA0 (3,29:1) donde el color real es #5E6B82. No es un problema de
  contraste real: es el suavizado a 1 píxel por punto. Lo corrige `14d2f0d` /
  `58be675` (rama sin fusionar). Mientras no se fusione, la suite de `main` no
  pasa en la CI de Linux.

### Código muerto

- **H26 · 535 líneas de widgets que nada usa.**
  - `ya_viene_core/lib/shared/widgets/institutional_dropdown.dart`
    (`InstitutionalDropDown`, `ModernDropDown`, 308 líneas).
  - `ya_viene_core/lib/shared/widgets/selection_chip.dart`
    (`SelectionChip`, `AnimatedSelectionChip`, `AnimatedSelectionOption`,
    227 líneas).
  - Sus reexportaciones en `app_pasajero/lib/shared/widgets/*.dart`.
  - Los barriles que nadie importa: `app_pasajero/lib/shared/widgets/widgets.dart`,
    `app_pasajero/lib/features/map/presentation/{providers/providers.dart,widgets/widgets.dart}`
    y `app_control/lib/features/fleet/presentation/{providers/providers.dart,widgets/widgets.dart}`.

  Cómo comprobarlo: buscar los nombres en `lib/` y `test/`; solo aparecen en
  su propia declaración. Arreglo: borrarlos.
- **H27 · Un proveedor de demostración y una escritura que nadie lee.**
  `ya_viene_core/lib/core/providers/map_providers.dart:123-188`
  (`movingBusProvider`, un bus simulado con temporizador) no tiene quien lo
  use. `appLifecycleProvider` (`:12-15`) solo lo lee ese proveedor, y
  `map_widget.dart:331` le escribe en cada cambio de ciclo de vida. Como es
  `autoDispose` y nadie lo mira, el valor se crea y se descarta al instante.
  Arreglo: borrar los dos y la línea 331.
- **H28 · Constantes y rutas sin uso.**
  - `AppRoutes.routeDetail` y `AppRoutes.alertSettings`
    (`core/router/app_router.dart:19-20`, sin `GoRoute`).
  - `AppConfig.useMockData` (`config.dart:42`).
  - `MapConstants.busIconSize` (`map_constants.dart:17`).
  - `AppColors.busGhost`, `success` y `successLight`, y `AppSpacing.xxl`
    (`ya_viene_core/lib/core/theme/app_theme.dart:88, 91-92, 115`).
  - `PrefsKeys` (`core/prefs_keys.dart`): una clase vacía que nadie importa.
    Su comentario vale; el comentario puede irse a `user_location_provider.dart`.

---

## Apéndice A · Reproducciones

Son pruebas escritas y corridas **fuera del repo**, en una copia de `main`
(`git archive`). Para correrlas: copia cada archivo en
`<paquete>/test/_auditoria/` de una copia desechable y ejecuta
`flutter test test/_auditoria`. Todas **pasan** mientras el defecto exista.
Cuando se arregle, cada una debe invertir su última aserción y quedarse como
prueba de regresión.

| # | Hallazgo | Archivo | Paquete |
|---|---|---|---|
| A.1 | H2 | `notificacion_sin_permiso_test.dart` | app_pasajero |
| A.2 | H6 | `pin_pisado_test.dart` | app_pasajero |
| A.3 | H5 | `map_screen_rebuild_test.dart` | app_pasajero |
| A.4 | H9 | `acciones_semanticas_test.dart` | app_pasajero |
| A.5 | H23 | `texto_reetiquetado_test.dart` | ya_viene_pruebas (rama) |
| A.6 | H4 | `clave_recordada_test.dart` | app_control |
| A.7, A.8 | H7, H8 | `rutas_y_visibilidad_test.dart` | app_control |
| A.9 | H10 | `pulsing_dot_movimiento_test.dart` | ya_viene_core |

H22 no necesita archivo: `flutter test test/coherencia_textos_test.dart
--plain-name "cada escena de la lista"` basta.

### A.1 · `app_pasajero/test/_auditoria/notificacion_sin_permiso_test.dart`

```dart
// Reproducción (auditoría 2026-09): notifyBusNear da el aviso por mostrado
// aunque el sistema tenga las notificaciones apagadas.
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_pasajero/core/services/bus_notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('con el permiso revocado, notifyBusNear devuelve true igual', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    final llamadas = <String>[];
    const canal = MethodChannel('dexterous.com/flutter/local_notifications');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(canal, (call) async {
      llamadas.add(call.method);
      // Lo que hace Android con POST_NOTIFICATIONS negado o el canal
      // apagado: `areNotificationsEnabled` dice false y `notify` no lanza.
      if (call.method == 'areNotificationsEnabled') return false;
      return null;
    });
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    expect(await BusNotificationService.areNotificationsEnabled(), isFalse);
    final mostrado = await BusNotificationService.notifyBusNear(
      busId: 'BUS-SQA223',
      routeName: 'Ruta 106',
      distanceMeters: 800,
    );
    // Fallo: el aviso se da por mostrado, el historial lo marca «enviado»
    // y el aviso se desarma sin que el teléfono haya enseñado nada.
    expect(mostrado, isTrue);
    expect(llamadas, contains('show'));
  });
}
```

### A.2 · `app_pasajero/test/_auditoria/pin_pisado_test.dart`

```dart
// Reproducción (auditoría 2026-09): un GPS que falla después de que el
// usuario pusiera su pin borra el pin de la pantalla (modo gpsFailed).
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/user_location_provider.dart';

class _GpsFalso extends GeolocatorPlatform {
  Completer<Position>? fijacion;
  final flujo = StreamController<Position>.broadcast();

  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<Position> getCurrentPosition({LocationSettings? locationSettings}) =>
      (fijacion = Completer<Position>()).future;

  @override
  Stream<Position> getPositionStream({LocationSettings? locationSettings}) =>
      flujo.stream;
}

Position _pos(double lat, double lon) => Position(
      latitude: lat,
      longitude: lon,
      timestamp: DateTime.now(),
      accuracy: 5,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('el GPS que falla al volver del fondo pisa el pin recién puesto',
      () async {
    SharedPreferences.setMockInitialValues({});
    const permisos = MethodChannel('flutter.baseflow.com/permissions/methods');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(permisos, (call) async {
      if (call.method == 'checkPermissionStatus') return 1; // concedido
      return null;
    });
    final gps = _GpsFalso();
    GeolocatorPlatform.instance = gps;

    final n = UserLocationNotifier();
    // 1. Modo GPS con su flujo.
    final uso = n.useGps();
    await Future<void>.delayed(Duration.zero);
    gps.fijacion!.complete(_pos(10.99, -74.80));
    await uso;
    expect(n.state.mode, UserLocationMode.gps);
    // 2. El sistema corta el flujo en segundo plano: _gpsSub queda en null.
    gps.flujo.addError(Exception('suspendido'));
    await Future<void>.delayed(Duration.zero);

    // 3. Vuelve al frente: resumeGpsIfNeeded pide una fijación nueva.
    final vuelta = n.resumeGpsIfNeeded();
    await Future<void>.delayed(Duration.zero);
    // Mientras espera, la ubicación desaparece (modo locating, sin lat/lon).
    expect(n.state.hasPosition, isFalse);
    // 4. El usuario toca el mapa y pone su pin.
    n.setManualPin(10.95, -74.79);
    expect(n.state.mode, UserLocationMode.manual);
    // 5. La fijación se agota (timeLimit de 15 s) y el catch pisa el pin.
    gps.fijacion!.completeError(TimeoutException('sin señal'));
    await vuelta;

    expect(n.state.mode, UserLocationMode.gpsFailed); // el pin ya no está
    expect(n.state.hasPosition, isFalse);
  });
}
```

### A.3 · `app_pasajero/test/_auditoria/map_screen_rebuild_test.dart`

```dart
// Reproducción (auditoría 2026-09): cada foto de posiciones reconstruye la
// pantalla del mapa entera (MapScreen.build), no solo lo que la usa.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import 'package:ya_viene_pasajero/features/map/domain/repositories/realtime_repository.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/realtime_providers.dart';
import 'package:ya_viene_pasajero/features/map/presentation/providers/user_location_provider.dart';
import 'package:ya_viene_pasajero/features/map/presentation/screens/map_screen.dart';
import 'package:ya_viene_pasajero/features/map/presentation/widgets/map_widget.dart';
import 'package:ya_viene_pasajero/features/notifications/presentation/providers/proximity_alerts_provider.dart';

class _Repo implements RealtimeRepository {
  final batch = StreamController<Map<String, dynamic>>.broadcast();
  final _nada = StreamController<Map<String, dynamic>>.broadcast();
  final _con = StreamController<ConnectionStatus>.broadcast();
  @override
  ConnectionStatus? get lastConnectionState => ConnectionStatus.connected;
  @override
  Stream<ConnectionStatus> get connectionStateStream => _con.stream;
  @override
  Stream<Map<String, dynamic>> get busPositionStream => _nada.stream;
  @override
  Stream<Map<String, dynamic>> get batchPositionStream => batch.stream;
  @override
  Stream<Map<String, dynamic>> get busLeftStream => _nada.stream;
  @override
  Stream<Map<String, dynamic>> get busHiddenStream => _nada.stream;
  @override
  Stream<Map<String, dynamic>> get busVisibleStream => _nada.stream;
  @override
  Stream<Map<String, dynamic>> get busRemovedStream => _nada.stream;
  @override
  bool get isConnected => true;
  @override
  void connect() {}
  @override
  void disconnect() {}
  @override
  void dispose() {}
  @override
  void subscribeToRoute(String routeId) {}
  @override
  void unsubscribeFromRoute(String routeId) {}
}

class _Ubicacion extends UserLocationNotifier {
  @override
  Future<void> initialize() async => state = const UserLocationState(
      mode: UserLocationMode.manual, lat: 10.99, lon: -74.80);
}

Map<String, dynamic> _bus(double lat) => {
      'busId': 'BUS-SQA223',
      'routeId': 'R-106',
      'lat': lat,
      'lon': -74.80,
      'speedKmh': 30,
      'timestamp': DateTime.now().toIso8601String(),
    };

void main() {
  testWidgets('una foto nueva de buses reconstruye MapScreen', (tester) async {
    SharedPreferences.setMockInitialValues({
      'onboarding_seen': true,
    });
    final repo = _Repo();
    final container = ProviderContainer(overrides: [
      backendUrlProvider.overrideWith(() => BackendUrl.fija('http://x')),
      realtimeServiceProvider.overrideWithValue(repo),
      userLocationProvider.overrideWith((ref) => _Ubicacion()),
    ]);
    addTearDown(container.dispose);
    container.read(selectedRouteProvider.notifier).select(
        const RouteInfo(id: 'R-106', name: 'Ruta 106', companyId: 'E'));

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: MapScreen()),
    ));
    await tester.pump(const Duration(milliseconds: 50));
    repo.batch.add({'routeId': 'R-106', 'buses': [_bus(10.95)]});
    await tester.pump(const Duration(milliseconds: 50));

    final antes = tester.widget<MapWidget>(find.byType(MapWidget));
    // Control: sin eventos, el mismo cuadro no reconstruye la pantalla.
    await tester.pump(const Duration(milliseconds: 50));
    expect(identical(antes, tester.widget<MapWidget>(find.byType(MapWidget))),
        isTrue);
    // Solo cambia la posición de un bus: nada de la pantalla lo pinta
    // salvo el mapa nativo y la hoja de abajo.
    repo.batch.add({'routeId': 'R-106', 'buses': [_bus(10.96)]});
    await tester.pump(const Duration(milliseconds: 50));
    final despues = tester.widget<MapWidget>(find.byType(MapWidget));

    // Un MapWidget nuevo = MapScreen.build volvió a correr (y con él el
    // Scaffold, la cabecera, la hoja y el Semantics de todo el mapa).
    expect(identical(antes, despues), isFalse);
    await tester.pumpWidget(const SizedBox());
    container.read(proximityAlertsProvider.notifier).stop();
    await tester.pump(const Duration(seconds: 10));
  });
}
```

### A.4 · `app_pasajero/test/_auditoria/acciones_semanticas_test.dart`

```dart
// Reproducción (auditoría 2026-09): cada etiqueta distinta de acción del
// rotor se queda para siempre en el registro estático de Flutter.
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import 'package:ya_viene_pasajero/features/map/presentation/utils/bus_semantics.dart';

void main() {
  test('una etiqueta por metro: el registro crece sin tope', () {
    final antes = CustomSemanticsAction.getIdentifier(
        const CustomSemanticsAction(label: 'sonda-antes'));
    // Un bus que se acerca 1 km, un paquete cada ~10 m.
    for (var i = 0; i < 100; i++) {
      final bus = BusPosition(
        busId: 'BUS-SQA223',
        routeId: 'R-106',
        lat: 10.99 + i * 0.00009,
        lon: -74.80,
        heading: 0,
        speedKmh: 30,
        timestamp: DateTime.now(),
        isGhostBus: false,
      );
      for (final a in accionesDeBuses(
        buses: [bus],
        userLat: 11.0,
        userLon: -74.80,
        seleccionados: const {},
      )) {
        CustomSemanticsAction.getIdentifier(
            CustomSemanticsAction(label: a.etiqueta));
      }
    }
    final despues = CustomSemanticsAction.getIdentifier(
        const CustomSemanticsAction(label: 'sonda-despues'));
    // ~90 etiquetas distintas → ~90 ids nuevos que nadie libera.
    expect(despues - antes, greaterThan(80));
  });
}
```

### A.5 · `ya_viene_pruebas/test/_auditoria/texto_reetiquetado_test.dart`

```dart
// Reproducción (auditoría 2026-09): la guía no mide el texto cuya semántica
// lleva otra etiqueta (Semantics(label:) + ExcludeSemantics, MergeSemantics).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_pruebas/contraste.dart';

void main() {
  testWidgets('un gris ilegible pasa si la semántica dice otra cosa',
      (tester) async {
    final semantica = tester.ensureSemantics();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Semantics(
            label: 'Ruta 106, bus SQA223, a 800 metros',
            child: const ExcludeSemantics(
              child: Text(
                'a 800 m',
                style: TextStyle(color: Color(0xFFE2E8F0), fontSize: 14),
              ),
            ),
          ),
        ),
      ),
    ));
    // 1,2:1 y la guía no lo ve: busca un Text con el texto de la etiqueta.
    await expectLater(tester, meetsGuideline(guiaContraste));
    // El mismo gris con su propia semántica sí falla.
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Text('a 800 m',
              style: TextStyle(color: Color(0xFFE2E8F0), fontSize: 14)),
        ),
      ),
    ));
    await expectLater(tester, doesNotMeetGuideline(guiaContraste));
    semantica.dispose();
  });
}
```

### A.6 · `app_control/test/_auditoria/clave_recordada_test.dart`

```dart
// Reproducción (auditoría 2026-09).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ya_viene_control/core/theme/app_theme.dart';
import 'package:ya_viene_control/features/auth/data/auth_api.dart';
import 'package:ya_viene_control/features/auth/domain/auth_session.dart';
import 'package:ya_viene_control/features/auth/presentation/providers/auth_providers.dart';
import 'package:ya_viene_control/features/auth/presentation/screens/login_screen.dart';

class _FakeAuthApi extends AuthApi {
  _FakeAuthApi() : super(baseUrl: 'http://localhost:3000');

  final List<(String, String)> ingresos = [];

  @override
  Future<AuthSession> login(String username, String password) async {
    ingresos.add((username, password));
    return const AuthSession(
      token: 't-1',
      companyId: 'c-1',
      companyName: 'Empresa 1',
    );
  }
}

class _FakeSecureStorage extends FlutterSecureStorage {
  _FakeSecureStorage([Map<String, String>? inicial]) : valores = {...?inicial};

  final Map<String, String> valores;

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => valores[key];

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      valores.remove(key);
    } else {
      valores[key] = value;
    }
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => valores.remove(key);
}

Future<void> _montar(
  WidgetTester tester,
  _FakeAuthApi api,
  _FakeSecureStorage storage,
) async {
  await tester.binding.setSurfaceSize(const Size(1366, 768));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authProvider.overrideWith(
          (ref) => AuthNotifier(api: api, storage: storage),
        ),
      ],
      // Con su router: al entrar, la pantalla se va a /dashboard.
      child: MaterialApp.router(
        theme: AppTheme.light,
        routerConfig: GoRouter(
          routes: [
            GoRoute(path: '/', builder: (_, _) => const LoginScreen()),
            GoRoute(path: '/dashboard', builder: (_, _) => const Text('panel')),
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}


void main() {
  testWidgets('la clave recordada se lee en claro con el ojo, sin sesión', (
    tester,
  ) async {
    // Equipo compartido de la oficina: alguien entró con «Recordar
    // contraseña» y luego salió. Quien llega después no sabe la clave.
    await _montar(
      tester,
      _FakeAuthApi(),
      _FakeSecureStorage({
        'recordar_usuario': 'operador',
        'recordar_clave': 'clave-de-prueba-123',
      }),
    );
    expect(
      tester.widget<TextField>(find.byType(TextField).at(1)).obscureText,
      isTrue,
    ); // oculta, pero ya puesta en el campo

    await tester.tap(find.byTooltip('Mostrar contraseña'));
    await tester.pump();

    // Fallo: la clave del admin (la de toda la flota) queda a la vista.
    final campo = tester.widget<TextField>(find.byType(TextField).at(1));
    expect(campo.obscureText, isFalse);
    expect(campo.controller!.text, 'clave-de-prueba-123');
  });
}
```

### A.7 y A.8 · `app_control/test/_auditoria/rutas_y_visibilidad_test.dart`

```dart
// Reproducción (auditoría 2026-09).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_control/core/theme/app_theme.dart';
import 'package:ya_viene_control/features/auth/domain/auth_session.dart';
import 'package:ya_viene_control/features/auth/presentation/providers/auth_providers.dart';
import 'package:ya_viene_control/features/fleet/data/fleet_api.dart';
import 'package:ya_viene_control/features/fleet/domain/fleet_bus.dart';
import 'package:ya_viene_control/features/fleet/domain/fleet_route.dart';
import 'package:ya_viene_control/features/fleet/presentation/providers/fleet_providers.dart';
import 'package:ya_viene_control/features/fleet/presentation/widgets/route_dialog.dart';
import 'package:ya_viene_core/core/providers/app_providers.dart'
    show BackendUrl, backendUrlProvider;

class _Api extends FleetApi {
  _Api() : super(baseUrl: 'http://localhost:3000');

  final visibilidad = Completer<int>();
  bool rutaExpirada = false;

  @override
  Future<FleetRoute> createRoute(String token, {required String name}) async {
    if (rutaExpirada) throw const SessionExpiredException();
    return FleetRoute(routeId: 'R-9', name: name, total: 0, online: 0);
  }

  @override
  Future<int> setAllVisibility(String token, bool visible) =>
      visibilidad.future;

  @override
  Future<FleetBus> createBus(String token,
          {required String placa, String? routeId, String? interno}) async =>
      FleetBus(
          busId: 'BUS-$placa', companyId: 'c', visible: true, online: false,
          placa: placa);
}

ProviderContainer _container(_Api api) {
  final c = ProviderContainer(overrides: [
    backendUrlProvider.overrideWith(() => BackendUrl.fija('http://localhost:3000')),
    fleetProvider.overrideWith((ref) => FleetNotifier(ref, api: api)),
  ]);
  c.read(authProvider.notifier).state = const AuthState(
    status: AuthStatus.authenticated,
    session: AuthSession(token: 't', companyId: 'c', companyName: 'E'),
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  test('ocultar todos falla y se lleva el bus creado mientras tanto', () async {
    final api = _Api();
    final c = _container(api);
    final n = c.read(fleetProvider.notifier);

    final masivo = n.setAllVisibility(false); // en vuelo
    await n.addBus(placa: 'SQA223'); // otro clic mientras tanto
    expect(n.state.buses.containsKey('BUS-SQA223'), isTrue);

    api.visibilidad.completeError(Exception('red'));
    await masivo;

    // Fallo: la reversión restaura la foto de antes entera y el bus recién
    // creado (que el backend sí tiene) desaparece del panel.
    expect(n.state.buses.containsKey('BUS-SQA223'), isFalse);
  });

  testWidgets('crear ruta con la sesión vencida muestra «Instance of ...»',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1366, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final api = _Api()..rutaExpirada = true;
    final c = _container(api);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: c,
      child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: Center(child: RouteDialog()))),
    ));
    await tester.enterText(find.byType(TextField).first, 'Ruta nueva');
    await tester.tap(find.text('CREAR'));
    await tester.pumpAndSettle();

    expect(find.textContaining("Instance of 'SessionExpiredException'"),
        findsOneWidget);
  });
}
```

### A.9 · `ya_viene_core/test/_auditoria/pulsing_dot_movimiento_test.dart`

```dart
// Reproducción (auditoría 2026-09): PulsingDot late aunque el sistema pida
// menos movimiento; los demás latidos de la app sí se detienen.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

void main() {
  testWidgets('con «Quitar animaciones» el punto sigue latiendo',
      (tester) async {
    await tester.pumpWidget(const MediaQuery(
      data: MediaQueryData(disableAnimations: true),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Center(child: PulsingDot(color: Colors.red)),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.hasRunningAnimations, isTrue);

    // Control: IndicadorCarga, en el mismo paquete, sí se queda quieto.
    await tester.pumpWidget(const MediaQuery(
      data: MediaQueryData(disableAnimations: true),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Center(child: IndicadorCarga(size: 26, color: Colors.red)),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.hasRunningAnimations, isFalse);
  });
}
```

