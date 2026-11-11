# El viaje completo: plan (Fase 0)

Siete funciones para que Ya Viene acompañe el viaje entero, no solo la
espera: planificar, saber cuándo llega, el saldo y la recarga de la tarjeta,
dónde recargar, quejarse con lugar y hora, y los viajes de origen a destino
para quien planea. Este documento es el plan; no trae código. Cada fase se
cierra entera (prueba roja y luego verde, analyze, builds, simulador) antes
de abrir la siguiente.

Escrito el 2026-11-11 sobre `referentes-movil` (`cde1c78`), backend `prueba`
(`7cc14ae`) y web `referentes-web` (`bb7fe46`).

## 0. Lo que manda sobre todo lo de abajo

- **Distancia, no minutos** (regla del producto 5, guion del pitch: «la
  distancia siempre es verdad»). Ninguna fase muestra un tiempo de llegada;
  la función 2 queda como propuesta y decisión del dueño (D24).
- **La app no toca el dinero**: ni número de tarjeta bancaria, ni datos de
  pago, ni cobro. La recarga se entrega al operador o al banco y la app solo
  muestra lo que vuelve.
- **Nada inventado como real**: ni endpoints, ni tarifas, ni puntos de
  recarga. Lo que no tenga fuente pública citada sale como «Simulación» o
  «Ejemplo» (D8), igual que la flota demo.
- **D3, el pasajero no tiene cuenta.** Nada de lo de abajo la crea.
- **Ley 1581** (T3.15, con abogado): quejas con ubicación, viajes de origen
  a destino y número de tarjeta son datos personales o pueden serlo. Cada
  una se diseña para guardar lo menos posible y queda en la lista del
  abogado antes de recoger datos reales.
- **Regla 14** (un solo bus seguido, la guía no se reanuda sola) choca con
  el viaje de dos buses. El plan la respeta y deja la pregunta al dueño.

## 1. Lo que ya existe y se reusa

| Pieza | Dónde | Para qué sirve aquí |
|---|---|---|
| `RutaMedible`, `SeguidorRuta` | `ya_viene_core/lib/core/geo/por_ruta.dart` | Proyectar un punto en la ruta (`proyectar`, `puntoDeEspera`, `pasosPorLaEspera`), el avance de un bus y la distancia por la ruta. El planificador se apoya entero en esto. |
| `rutas.json` (15 rutas) | `ya_viene_core/assets/data/rutas.json` | Recorridos de las rutas. **Ninguna trae paradas** (`paradas: []` en las 15): subir y bajar se calcula sobre la línea, no sobre paraderos. |
| `BusStop` | `ya_viene_core/lib/core/models/bus_stop.dart` | Modelo de parada fija o informal; hoy sin datos. Se reusa si llegan paraderos. |
| `centroCeldaBusqueda` | `ya_viene_core/lib/core/geo/celda_busqueda.dart` y `src/data/busquedas.ts` | La rejilla de 150 m de D17. Las quejas y el origen a destino se agregan sobre ella o un múltiplo. |
| Buzón (D14) | `app_pasajero/lib/features/buzon/`, `src/data/reportes.ts`, migración 26 | La queja con lugar y hora extiende este formulario y esta ruta; el limitador (5 cada 10 min por IP) y la limpieza de texto se quedan. |
| Reportes del panel (D17) | `app_control/.../screens/reportes_screen.dart`, `reportes_provider.dart`, `GET /api/panel/busquedas*` | Las quejas y el origen a destino entran como pestañas o capas de esta pantalla, con su filtro de fecha. |
| `colorEmpresa`, `EstiloRuta`, `coloresCalor` | app y core | Color de cada empresa, ruta verde sobre orla blanca, escala de calor del panel. |
| `Resorte`, `curvaEntrada`, `curvaCambio`, `curvaRebote` | `app_motion.dart` | Todo movimiento nuevo. |
| `Dialogo`, `AvisoTarjeta`, `Ventana`, `CabeceraDegradada` | app y panel | Ventanas y cabeceras propias; nada de `AlertDialog` ni `SnackBar`. |
| `flutter_secure_storage` | ya en `app_control` | El número de tarjeta del pasajero (fase 5) va en el Llavero o el Keystore. |
| `url_launcher` | ya en las dos apps | Entregar la recarga al operador o al banco (fase 6). |

## 2. El modelo del dominio común

Tipos nuevos en `ya_viene_core` (lo que comparten app y panel) y su espejo
en el backend donde viajan por la red. Nombres en el idioma del dominio,
como el resto del código.

```text
Lugar            { punto: GeoPoint, origen: gps | pin | sitio, nombre? }
                 Dónde empieza o termina un viaje. Sin `nombre` si vino del
                 GPS o del pin (el mapa no tiene nombres de sitios).

Subida / Bajada  { ruta: routeId, avance: double (m por la ruta),
                   punto: GeoPoint (en la línea), caminata: double (m) }
                 El punto de la ruta donde se toma o se deja el bus. Sale de
                 `RutaMedible.pasosPorLaEspera`; no es un paradero.

Tramo            sealed: TramoAPie { desde, hasta, metros (en línea recta) }
                       | TramoEnBus { ruta, empresa, subida, bajada,
                                      metrosPorLaRuta }
Transbordo       { bajada del tramo anterior, subida del siguiente,
                   caminata } (un TramoAPie entre dos TramoEnBus)
Viaje            { origen: Lugar, destino: Lugar, tramos: List<Tramo> }
                 Con `buses` (1 o 2), `caminataTotal`, `metrosEnBus`. Nunca
                 un tiempo.
BusQueViene      { busId, placa, metrosHastaLaSubida (por la ruta), aldia }
                 El bus en vivo más cercano antes de la subida, en sentido
                 de la ruta. Se calcula en la app, no se guarda.

PuntoDeRecarga   { id, nombre, punto, direccion, horario?, fuente: Fuente }
Fuente           { nombre, url, fecha } | ejemplo
                 Todo punto lleva de dónde salió; sin fuente, se pinta
                 como «Ejemplo».

Tarjeta          { numero (solo en el teléfono), alias? }
Saldo            { valor: entero en pesos, consultado: DateTime, origen:
                   simulacion | operador }
ConsultaSaldo    sealed: Saldo | SinRed | NoEncontrada | NoDisponible
Recarga          { referencia, estado: pendiente | aprobada | rechazada |
                   desconocida } (lo que devuelve el operador, nada más)

Queja            { motivo: Motivo, texto, ruta?, bus?, lugar?: celda,
                   ocurrio: DateTime (a la hora), conLugar: bool }
Motivo           enum: no paró, iba lleno, mal trato, conducción, otra ruta,
                 estado del bus, otro (las opciones exactas las fija el
                 dueño; ver preguntas)

ParOrigenDestino { origen: celda, destino: celda, dia, conteo ≥ 5 }
```

Dos piezas de lógica pura nuevas en el core, sobre `RutaMedible`:

- **`recorridoDirigido(desde, hasta)`**: metros por la ruta en su sentido.
  En una ruta circular es `(hasta - desde) mod largo`; en una de ida y
  vuelta, solo si `hasta ≥ desde`. Hoy `_entre` toma el menor de los dos
  sentidos, que sirve para «a qué distancia viene» pero no para un viaje:
  el bus no va en reversa.
- **`planear(origen, destino, rutas, opciones)`**: devuelve los viajes
  ordenados. Ver la fase 3.

## 3. Las siete funciones

### 3.1 Quejas con lugar y hora (fase 1)

- **Qué resuelve.** Hoy el buzón dice «algo falla» sin decir dónde ni en
  qué bus; el equipo no puede pasárselo a la empresa y la empresa no puede
  ver dónde se repite. Con ruta, bus, lugar y hora, la queja se vuelve un
  dato que sirve.
- **Datos.** Los pone el pasajero. La app los propone (la ruta y el bus que
  está siguiendo, su punto, la hora de ahora) y todos se pueden cambiar o
  quitar. El lugar solo se manda con un sí explícito en el formulario, que
  arranca apagado; sin él la queja va sin lugar. El punto viaja como el
  centro de su celda de 150 m (D17), no como coordenada exacta, y la hora
  redondeada a la hora.
- **Toca.** App (el formulario del buzón crece: tipo «queja» con motivo,
  ruta, bus, lugar y hora), backend (`leerReporte` acepta los campos
  nuevos y los valida en la frontera: ruta que existe, bus de esa ruta,
  celda alineada y dentro del área de servicio como en D17, hora no futura
  y no más vieja que 7 días; migración nueva), panel (Reportes: mapa con
  las quejas por celda y lista filtrable por ruta, motivo y fecha; cada
  empresa ve solo las de sus rutas). Web no.
- **Cambio de fondo frente a D14.** Hoy el reporte se borra al salir por
  correo. Para que el panel lo muestre hay que guardarlo, con retención y
  dueño (la empresa). Eso es D18.
- **Pruebas.** Backend: validación campo por campo (roja con cada entrada
  mala), alcance por empresa (la empresa A no ve las de B), retención,
  limitador, correo con los campos nuevos y sin ellos. App: el
  consentimiento arranca apagado y sin él no viaja `lugar` (prueba que lee
  el cuerpo de la petición), los estados de envío ya existentes. Panel:
  agregado por celda y lista con datos de prueba, vacío y error.
- **Riesgos.** Una queja anónima puede señalar a un conductor sin pruebas:
  el panel la rotula «Sin verificar» y no muestra placa en el mapa
  agregado. Ubicación más hora de una persona: celda y hora redondeada,
  consentimiento explícito, nada de IP ni dispositivo, y el abogado. Spam:
  el limitador de D14 se queda y la cola sigue con tope.

### 3.2 Puntos de recarga en el mapa (fase 2)

- **Qué resuelve.** Dónde recargar cerca, sin salir de la app.
- **Datos.** Solo de una fuente pública citada (portal del operador, del
  AMB o de datos.gov.co) con su URL y fecha en cada punto. Hoy no
  conozco una lista pública verificable de puntos de recarga de buses
  urbanos en Barranquilla; si no aparece, la capa sale con puntos de
  ejemplo rotulados «Ejemplo» y la fuente real queda en «Esperando a
  alguien de afuera». No se copia de Google Maps (licencia).
- **Toca.** Core (modelo y lectura del archivo, con su prueba de esquema),
  app (capa en MapLibre que se enciende y apaga, ficha del punto con
  dirección, horario si la fuente lo trae y la fuente, estado vacío «No hay
  puntos de recarga cerca», error de lectura). Backend solo si los puntos se
  sirven de allí para poder cambiarlos sin publicar la app. Panel y web no.
- **Pruebas.** Esquema del archivo (cada punto con fuente o marca de
  ejemplo), filtro por cercanía, ficha con y sin horario, rótulo «Ejemplo»
  siempre que no haya fuente (prueba espejo del literal).
- **Riesgos.** Datos viejos que mandan a la gente a un punto cerrado: la
  ficha dice la fecha de la fuente. Ruido en el mapa: la capa se apaga por
  defecto y no lleva nombres pintados (regla del mapa sin nombres de
  negocios).

### 3.3 Planificador de viaje (fase 3)

- **Qué resuelve.** «Estoy aquí, voy allá»: qué ruta tomar, dónde subir,
  dónde bajar, cuánto caminar, si hay que cambiar de bus, y qué bus en vivo
  viene y a qué distancia. Sin minutos.
- **Datos.** `rutas.json` (recorridos), los buses en vivo del socket, y el
  origen y destino del pasajero. Sin paraderos: subir y bajar son puntos de
  la línea. La caminata se mide en línea recta y se dice así («unos 300 m
  a pie»); no hay grafo de calles ni servicio de rutas a pie.
- **Lógica pura en el core** (`ya_viene_core/lib/core/viaje/`):
  1. Para cada ruta, los pasos cerca del origen y del destino
     (`pasosPorLaEspera`, que ya separa la 23 de ida de la 24 de vuelta).
  2. **Directo**: una ruta con paso cerca del origen y del destino, con
     `recorridoDirigido(subida, bajada)` finito; se queda el par que deja
     menos recorrido.
  3. **Con un trasbordo**: puntos donde dos rutas pasan a menos de la
     caminata de trasbordo; se calculan una vez al cargar las rutas
     (15 rutas, 105 pares) con un índice de rejilla, no en cada búsqueda.
  4. Orden: menos buses, luego menos caminata total, luego menos metros en
     bus. Hasta 3 opciones. Topes (caminata máxima, trasbordos) como
     parámetros con el valor que fije el dueño.
  5. **BusQueViene**: con `SeguidorRuta.avanceDe`, el bus de la ruta más
     cercano antes de la subida en sentido de la ruta; si no hay, «Sin
     buses en vivo en esta ruta» (el mismo estado de la hoja).
  Pruebas exhaustivas: rutas sintéticas (recta, circular, ida y vuelta por
  calles paralelas, dos rutas que se cruzan, dos que corren juntas),
  origen igual a destino, origen fuera de toda ruta, ninguna opción, bus
  justo en la subida, bus recién pasado (da la vuelta en circular, no en
  ida y vuelta), y propiedades (el recorrido dirigido nunca es negativo,
  la caminata nunca supera el tope). Más un juego con las 15 rutas reales
  que fija resultados conocidos.
- **UI** (referencia: Citymapper y Transit). Dos campos arriba (De, A) que
  arrancan en «Tu ubicación» y «Toca el mapa»; las opciones como tarjetas
  con la tira de tramos (a pie, insignia de ruta en `colorEmpresa`, a pie)
  y, a la derecha, la cifra grande de metros del bus que viene, como en la
  hoja. Elegir una opción dibuja en el mapa la caminata punteada solo aquí
  (en el mapa normal la punteada no gustó), la ruta en verde sobre orla y
  los puntos de subida y bajada; el botón «Ir» abre el mapa con esa
  empresa y ruta, con el pin en la subida, listo para el aviso. Estados:
  sin origen, sin destino, buscando, sin opciones («Ninguna ruta pasa
  cerca de los dos puntos»), sin red, sin buses en vivo.
- **Toca.** Core (lógica y modelo), app (pantalla y entrada desde la barra
  de búsqueda). Backend y panel no; web solo si el dueño quiere mostrarlo.
- **Riesgos.** Recorridos de KMZ con errores dan planes malos (Coochofal):
  el juego de rutas reales los destapa. Sin buscador de sitios el
  pasajero solo puede usar GPS o el pin (pregunta al dueño). La guía de
  dos buses choca con la regla 14: el botón «Ir» lleva solo el primer
  tramo; el segundo se arma a mano con su propio botón.
- **Rendimiento.** Una búsqueda debe tardar menos de 50 ms en un iPhone de
  gama media con las 15 rutas; prueba con cronómetro en el core.

### 3.4 Viajes de origen a destino (fase 4)

- **Qué resuelve.** Que la empresa y el AMB vean desde dónde hacia dónde
  quiere moverse la gente, no solo qué ruta se busca.
- **Datos.** No hay recaudo ni cuenta, así que no hay viajes reales: lo
  único honesto es la **intención** del planificador, la búsqueda de
  origen y destino. Se rotula así en el panel («Viajes buscados», no
  «viajes hechos»). Se manda solo al tocar «Ir», no en cada búsqueda.
- **Privacidad.** Un par origen y destino repetido señala casa y trabajo,
  así que va más grueso que D17: celdas de 4 × 4 de la rejilla de 150 m
  (unos 600 m), hora redondeada a franja de 3 horas, k ≥ 5 por par y día
  de Bogotá, retención de 13 meses, nada de IP ni dispositivo. D20.
- **Toca.** App (manda el par al tocar «Ir»), backend (ruta con limitador
  propio, tabla agregada, consulta con k ≥ 5, alcance por empresa: la
  empresa ve los pares cuyo plan usa sus rutas), panel (Reportes: líneas
  de deseo entre centros de zona, grosor por conteo, y una matriz de las
  10 zonas que más salen). Web no.
- **Pruebas.** k ≥ 5 por día (un par con 4 no sale; dos rangos solapados
  no dejan restar, AUD29-01), alineación de celdas, alcance por empresa,
  retención, limitador. Panel: líneas y matriz con datos de prueba, vacío
  («Aún no hay suficientes viajes para mostrar») y error.
- **Riesgos.** El mismo que AUD29-07: un POST anónimo puede inflar los
  datos. Limitador por IP y tope por día; queda en el informe de riesgos.

### 3.5 Saldo de la tarjeta SIBUS (fase 5)

- **Qué resuelve.** Saber cuánto queda sin ir a un punto.
- **Datos.** No hay API pública conocida de SIBUS ni de ningún operador de
  recaudo de Barranquilla. La consulta va detrás de una interfaz
  (`ProveedorSaldo`) con una sola implementación, `SaldoSimulado`, que
  devuelve valores de ejemplo y se pinta «Simulación». Cuando haya un
  proveedor real se escribe la segunda, sin tocar la UI.
- **El número de la tarjeta.** Solo en el teléfono, en el Llavero (iOS) o
  el Keystore (Android) con `flutter_secure_storage`; nunca en el backend,
  en los logs ni en las analíticas. En pantalla, enmascarado (los 4
  últimos). «Quitar tarjeta» lo borra al instante, con confirmación propia
  (`Dialogo`). Al desinstalar en iOS el Llavero sobrevive: se borra al
  primer arranque si la app no tiene su marca de instalación.
- **Toca.** App (pantalla en Más, guardado seguro, consulta, estados:
  sin tarjeta, consultando, saldo con hora de consulta, sin red, tarjeta
  no encontrada, servicio no disponible). Backend solo si el proveedor real
  exige un intermediario; con el simulado, no. Panel y web no.
- **Pruebas.** Guardado, lectura y borrado contra un almacén falso; el
  número nunca aparece en el `toString` ni en el texto de un error; cada
  estado de `ConsultaSaldo` con su pantalla; validación del formato (sin
  inventar el formato real: lo da la fuente; mientras tanto solo dígitos
  con largo acotado).
- **Riesgos.** Choca con la línea del pitch: «No buscamos ser como SIBUS»
  y «No competimos con una plataforma de recaudo». Ver pregunta 1. Un
  número de tarjeta de transporte puede ligar viajes a una persona: por
  eso no sale del teléfono.

### 3.6 Recarga (fase 6)

- **Qué resuelve.** Recargar sin hacer fila.
- **Cómo, sin tocar el dinero.** La app abre la página o la app del
  operador o del banco (`url_launcher`, enlace universal o app link) con
  una referencia opaca, y vuelve por un enlace de retorno
  (`yaviene://recarga?referencia=...&estado=...`). El estado que llega por
  el enlace no se cree: se consulta al proveedor con la referencia, y
  mientras no responda se muestra «Pendiente». La app nunca ve número de
  tarjeta bancaria, cuenta ni monto cobrado más allá de lo que el
  proveedor diga. Proveedor simulado, rotulado «Simulación», con página de
  pago de mentira servida en local para las pruebas.
- **Toca.** App (botón, entrega, retorno, estados: pendiente, aprobada,
  rechazada, desconocida, sin red). Backend solo si el proveedor real lo
  exige. Panel y web no.
- **Seguridad** (`security-and-hardening`, revisión completa en la fase):
  el enlace de retorno es entrada no confiable (se valida forma y largo y
  se ignora todo lo demás), una referencia solo sirve una vez, nada de
  WebView con formulario de pago dentro de la app (phishing y PCI), solo
  dominios en lista cerrada, y los logs no llevan referencia completa.
- **Pruebas.** Enlace de retorno con basura, con referencia ajena, repetido;
  estado que dice «aprobada» y el proveedor dice «rechazada» (gana el
  proveedor); sin red a la vuelta.
- **Riesgos.** Fraude por enlaces falsos que imitan el retorno: por eso el
  estado siempre se consulta. Y el mismo choque con el pitch de la 3.5.

### 3.7 Hora de llegada (fase 7, solo propuesta)

- La regla 5 del producto y el guion del pitch dicen distancia, no
  minutos. Esta fase no escribe código: deja la propuesta y la decisión en
  FALTANTES (D24, abierta).
- **Propuesta.** Si algún día se muestra, que no sea una promesa: un rango
  tomado de lo que tardaron los buses de esa ruta en ese tramo y a esa hora
  los últimos días («suele tardar de 8 a 15 min»), solo con datos reales
  (no con la flota simulada), con el rango ancho a propósito y debajo de
  la distancia, nunca en su lugar. Sin datos de piloto no hay con qué.

## 4. Decisiones nuevas (borradores)

Viven aquí mientras son borradores. Cada una pasa a
`YaVieneBackend/docs/decisiones/` y a su índice en el commit que cierra su
fase, con el sí del dueño a las preguntas que la tocan.

### D18. La queja del pasajero lleva ruta, bus, lugar y hora, y la ve la empresa

- **Toca**: backend, app pasajero, panel. **Estado**: propuesta.
- **La pregunta.** El buzón (D14) borra el reporte al mandarlo por correo.
  ¿Se guarda la queja para mostrarla en el panel, y con qué datos?
- **Lo propuesto.** Un tipo nuevo, «queja», con motivo, ruta, bus, celda
  de 150 m y hora redondeada, todos opcionales y editables; el lugar solo
  con consentimiento explícito que arranca apagado. Se guarda 13 meses y
  la ve la empresa de la ruta; el correo al equipo sigue. Problemas y
  sugerencias siguen como en D14.
- **Por qué.** Sin guardarla no hay mapa ni lista; sin celda y hora
  redondeada, la queja dice dónde estaba una persona a una hora.
- **La otra opción.** Coordenada exacta y minuto: más útil para la empresa,
  pero ubica a la persona. Se descarta salvo que el abogado diga otra cosa.

### D19. El planificador da distancia y tramos, nunca minutos, y guía un tramo a la vez

- **Toca**: core, app pasajero. **Estado**: propuesta.
- **Lo propuesto.** Viajes de hasta dos buses con subida y bajada sobre la
  línea (no hay paraderos), caminata en línea recta dicha así, el bus en
  vivo que viene con su distancia por la ruta. «Ir» arma solo el primer
  tramo; el segundo tiene su propio botón al bajarse. La regla 14 se
  queda.
- **Por qué.** Sin minutos por la regla 5; un tramo a la vez para no
  cambiar la regla 14 sin el dueño.
- **La otra opción.** Guía continua de dos buses (lo que pide FALTANTES,
  «Después»): exige cambiar la regla 14.

### D20. Los viajes de origen a destino se cuentan como intención, en zonas de 600 m y con k ≥ 5

- **Toca**: backend, app pasajero, panel. **Estado**: propuesta.
- **Lo propuesto.** Cuenta el par de zonas al tocar «Ir» en el
  planificador; zonas de 4 × 4 celdas de D17, franja de 3 horas, k ≥ 5 por
  par y día de Bogotá, 13 meses, sin IP ni dispositivo. En el panel se
  llama «Viajes buscados».
- **Por qué.** No hay recaudo ni cuenta: lo único que hay es la intención,
  y un par fino señala casa y trabajo.

### D21. Los puntos de recarga salen de una fuente pública citada o dicen «Ejemplo»

- **Toca**: core, app pasajero. **Estado**: propuesta.
- **Lo propuesto.** Cada punto con fuente, URL y fecha; sin fuente, rótulo
  «Ejemplo» como la flota demo (D8). Capa apagada por defecto.

### D22. El número de la tarjeta vive solo en el teléfono; el saldo, detrás de un proveedor

- **Toca**: app pasajero. **Estado**: propuesta, choca con el pitch.
- **Lo propuesto.** Número en el Llavero o Keystore, enmascarado, borrable;
  proveedor `SaldoSimulado` rotulado «Simulación» hasta que exista uno real
  con convenio.

### D23. La recarga se entrega al operador o al banco; la app solo lee el resultado

- **Toca**: app pasajero. **Estado**: propuesta, choca con el pitch.
- **Lo propuesto.** Enlace al proveedor con referencia opaca, retorno
  validado y estado consultado al proveedor; nada de WebView de pago;
  proveedor simulado.

### D24. Hora de llegada

- **Toca**: app pasajero, web. **Estado**: **abierta**, decide el dueño.
- **Lo propuesto.** Seguir sin minutos. Si se abre, un rango con datos
  reales del piloto, debajo de la distancia (sección 3.7).

## 5. Preguntas que solo tú puedes responder

1. **SIBUS y recarga frente al pitch.** El guion dice «No buscamos ser
   como SIBUS» y «No competimos con una plataforma de recaudo». ¿Sigo con
   saldo y recarga (fases 5 y 6) con proveedor simulado, o esperan a un
   convenio? ¿Y hoy qué tarjeta usa de verdad el bus urbano de
   Barranquilla?
2. **Quién ve las quejas.** ¿Las ve la empresa del bus, con el texto, o
   solo el equipo? ¿13 meses está bien?
3. **Motivos de queja.** ¿Te sirven no paró, iba lleno, mal trato,
   conducción, otra ruta, estado del bus, otro?
4. **Cómo dice el pasajero a dónde va.** Hoy no hay buscador de sitios y
   el mapa no lleva nombres. ¿Solo GPS y pin, o se busca una fuente
   (barrios del AMB, un geocodificador pago)?
5. **Topes del planificador.** ¿Caminata máxima de 600 m y un solo
   trasbordo?
6. **Dos buses.** ¿Se queda la regla 14 (el segundo tramo se arma con su
   botón) o se cambia para guiar el viaje entero?
7. **El planificador antes del piloto.** FALTANTES lo dejaba para la fase 2
   del piloto. ¿Se adelanta ahora?
8. **Hora de llegada.** ¿Sigue fuera (D24)?

## 6. Orden y cierre de cada fase

| Fase | Función | Repos | Cierra con |
|---|---|---|---|
| 1 | Quejas | backend, app, panel | `npm test`, `tsc`, analyze y test del pasajero y el panel, build iOS y simulador, capturas del panel |
| 2 | Puntos de recarga | core, app | analyze y test del core y sus dependientes, build iOS y simulador |
| 3 | Planificador | core, app | lo mismo, más la prueba de tiempo |
| 4 | Origen a destino | backend, app, panel | como la fase 1 |
| 5 | Saldo | app | analyze y test, build iOS y simulador |
| 6 | Recarga | app | lo mismo, más la revisión de seguridad |
| 7 | Hora de llegada | ninguno | propuesta en FALTANTES |

Cada estado nuevo entra en `inventario-estados.md` en el commit de su fase.
Rama `viaje-completo` en cada repo que se toque, sin push.
