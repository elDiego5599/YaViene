// Números que antes estaban desperdigados por el mapa. Centralizarlos aquí
// evita que un cambio en un sitio rompa otro y que el próximo dev adivine
// de dónde viene cada valor.
class MapConstants {
  MapConstants._();

  /// Radio para hit-test de buses (proyección + fallback rect).
  static const double busHitRadius = 32.0;

  /// Rect del área guía de buses (usado como fallback visual).
  static const double guideBusRectSize = 76.0;

  /// Inset inferior que deja la tarjeta de guía sobre el mapa (evita navbar).
  static const double guideBottomInset = 310.0;

  /// Ancho del icono de bus (Flat) en el canvas de 80 px.
  static const double busIconSize = 80.0;

  // --- Hasta dónde llega el mapa ---
  //
  // Un cuadrado de 41 × 41 km sobre el área metropolitana: Malambo y Soledad
  // al sur, Eduardo Santos (La Playa) al suroccidente, el norte de
  // Barranquilla, la ciénaga de Mallorquín y Bocas de Ceniza arriba. Ahí
  // caben las rutas enteras de Sobusa y Coolitoral (`rutas.json`: lat
  // 10,887–11,039 · lon −74,877–−74,769) y todo el casco urbano que las
  // rodea, con sitio de sobra para arrastrar el mapa y mirar alrededor.
  //
  // El cuadrado creció —y sobre todo creció hacia el norte— porque el de
  // 28 km apenas era más grande que la propia pantalla: a zoom mínimo la
  // cámara solo podía correrse un par de kilómetros y el mapa se sentía
  // clavado, con el norte de la ciudad detrás de una pared invisible.
  //
  // Es cuadrado a propósito, y cuadrado en kilómetros, no en grados: 0,374°
  // de latitud son 41,4 km y 0,3784° de longitud a esta altura también.
  // Así el dedo recorre lo mismo hacia el norte que hacia el oriente antes
  // de topar con el borde, en vez de chocar antes por un lado que por el
  // otro.
  //
  // El mínimo tampoco es libre: a [zoomMinimo] la pantalla tiene que caber
  // dentro del cuadrado. Android sujeta el centro de la cámara e iOS sujeta
  // lo que se ve, y esa es la única medida en la que las dos se comportan
  // igual. `map_area_test` y `rutas_json_test` lo comprueban.
  static const double areaSurLat = 10.790;
  static const double areaNorteLat = 11.164;
  static const double areaOesteLon = -75.0035;
  static const double areaEsteLon = -74.6251;

  /// El centro del cuadrado, que es más o menos el corazón del área servida:
  /// el sur de Barranquilla, a medio camino entre el norte y Malambo.
  static const double areaCentroLat = 10.977;
  static const double areaCentroLon = -74.8143;

  /// El plano más lejano: el área metropolitana entera llenando la pantalla,
  /// de Malambo al norte de Barranquilla, y nada más.
  ///
  /// Es también el zoom con el que abre el mapa: el primer gesto de alejar ya
  /// está en el tope, sin el salto de seis niveles de teselas hasta ver el
  /// Caribe entero que había antes.
  ///
  /// Era 11,4 hasta que entró Coolitoral: su red se sale un poco hacia los
  /// dos lados de la de Sobusa (0,108° de ancho en vez de 0,100°) y en un
  /// teléfono de 402 pt ya no cabía entera. A 11,35 cabe y la pantalla
  /// alta sigue dejando 12 km para arrastrar (`map_area_test`).
  static const double zoomMinimo = 11.35;

  /// Y el más cercano: manzana y media, que es donde el bus deja de ser un
  /// punto y se ve por qué carril viene.
  static const double zoomMaximo = 18.5;
}
