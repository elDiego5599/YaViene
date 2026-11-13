# D25: El buscador de lugares es un índice local de datos abiertos

- **Decidida**: 2026-11-12. **Toca**: `ya_viene_core`, `app_pasajero`.
- **Estado**: decidida y construida (índice, buscador, widget `BuscaLugar`). Falta conectarlo al planificador del viaje completo.

## La pregunta

Para planificar un viaje la persona escribe de dónde sale y a dónde va. ¿De dónde salen las sugerencias: de un servicio de geocodificación de fuera o de un índice que viaja con la app?

## Lo decidido

**Un índice local, armado de datos abiertos, que se consulta sin red.**

- **Fuentes y licencia** (la app las muestra bajo los resultados, `BuscadorDeLugares.atribucion`):
  - OpenStreetMap, Colaboradores de OpenStreetMap, ODbL 1.0: 508 barrios, 2.513 vías y 1.345 sitios de Barranquilla, Soledad, Malambo, Galapa y Puerto Colombia (consulta del 2026-11-12).
  - Barrios de Barranquilla según el POT, Alcaldía Distrital de Barranquilla, CC BY-SA 4.0 (datos.gov.co, 2021-12-30): 16 barrios que OSM no trae.
- **Dónde vive**: `ya_viene_core/assets/data/lugares_osm.json` (430 KB) y `lugares_pot.json` (1 KB), que genera `ya_viene_core/tool/lugares/construir.mjs` y se regenera con él cuando haga falta.
- **Interfaz**: `BuscadorDeLugares.buscar(consulta, maximo, sesgo)` devuelve `Sugerencia` (lugar, tipo, contexto). `BuscadorLocal` la implementa y `BuscadorFalso` sirve a las pruebas y los arneses.
- **Qué entiende**: tildes, mayúsculas, abreviaturas de la nomenclatura (Cra, Kr, Cl), una letra mal escrita en palabras (no en números: la 46 no es la 47), la última palabra como prefijo, esquinas («Calle 72 con 46») y placas («Calle 72 # 46-20», a 20 m de la esquina). Ordena por relevancia y, entre iguales, por cercanía al sesgo.
- **Recientes**: `RecientesDeLugares`, solo en el teléfono, que la persona borra de uno en uno o todos.
- **Resultado**: `Lugar { punto, origen: gps | pin | sitio, nombre? }`, la entrada del planificador.

## Por qué

- **Privacidad (Ley 1581)**: lo que alguien escribe como origen y destino dice dónde vive y a dónde va. Un servicio de fuera lo recibiría con su IP. El índice local no manda nada a nadie y D3 (el pasajero no tiene cuenta) se mantiene.
- **Sin red también**: el bus se espera en la calle, con datos flojos. Buscar funciona igual.
- **Nominatim no sirve para autocompletar**: su política de uso lo prohíbe, y un servicio de pago aparte sería una dependencia, una clave y un costo para algo que una ciudad de este tamaño cabe en menos de medio megabyte.
- **Nada inventado**: cada fila sale de un dato abierto con su licencia citada. Lo que no está, no se sugiere, y la persona siempre puede elegir en el mapa.
- **Rapidez medida**: la prueba `buscador_real_test.dart` corre el índice de verdad y exige p95 por debajo de 50 ms.

## Límites que se aceptan

- OSM nombra «Avenida Olaya Herrera» a casi toda la Carrera 46, así que «Calle 72 con 46» no siempre encuentra esquina. La persona puede escribir el nombre de la avenida o elegir en el mapa.
- El índice envejece: hay que regenerarlo con `construir.mjs` antes de cada entrega que lo necesite.
