// Construye los índices locales del buscador de lugares (D25):
//   assets/data/lugares_osm.json  barrios, vías y sitios de OpenStreetMap (ODbL 1.0)
//   assets/data/lugares_pot.json  barrios del POT de Barranquilla que OSM no trae
//                                 (datos.gov.co qui6-qeux, CC BY-SA 4.0)
//
// Uso, desde ya_viene_core:  node tool/lugares/construir.mjs
//
// Cada archivo lleva su fuente, su licencia y la fecha de los datos, y los dos
// se quedan separados para que cada uno conserve su licencia (las dos piden
// compartir igual; mezclarlas en una sola base no es seguro). Nada se escribe
// a mano: si un lugar no está en una de las dos fuentes, no entra.
//
// Se corre a mano cuando se quiera refrescar el índice; la app no llama a
// Overpass ni a datos.gov.co.

import { writeFile } from 'node:fs/promises';

const OVERPASS = 'https://overpass-api.de/api/interpreter';
const POT_FILAS = 'https://www.datos.gov.co/resource/qui6-qeux.json?$limit=5000';
const POT_META = 'https://www.datos.gov.co/api/views/qui6-qeux.json';
const AGENTE = 'YaViene-indice-lugares/1.0 (construccion manual, sin uso en vivo)';

// El área metropolitana de Barranquilla (Ley 1625 de 2013, AMB): los cinco
// municipios por donde pasan las rutas. La caja descarta homónimos de otros
// departamentos.
const MUNICIPIOS = ['Barranquilla', 'Soledad', 'Malambo', 'Galapa', 'Puerto Colombia'];
const CAJA = '10.80,-74.98,11.10,-74.70';

// Calles que la gente nombra al ubicarse. Sin `service` (parqueaderos,
// entradas de conjuntos) ni caminos de tierra sin nombre.
const VIAS =
  'trunk|trunk_link|primary|primary_link|secondary|secondary_link|' +
  'tertiary|tertiary_link|unclassified|residential|living_street|pedestrian';

// Sitios que sirven de referencia para tomar un bus, con el rótulo que se
// muestra en gris. El orden decide el rótulo cuando un sitio trae varias
// etiquetas.
const SITIOS = [
  ['aeroway', 'aerodrome', 'Aeropuerto'],
  ['amenity', 'bus_station', 'Terminal de buses'],
  ['public_transport', 'station', 'Estación'],
  ['shop', 'mall', 'Centro comercial'],
  ['amenity', 'hospital', 'Hospital'],
  ['amenity', 'clinic', 'Clínica'],
  ['amenity', 'university', 'Universidad'],
  ['amenity', 'college', 'Institución educativa'],
  ['amenity', 'school', 'Colegio'],
  ['amenity', 'library', 'Biblioteca'],
  ['amenity', 'marketplace', 'Mercado'],
  ['amenity', 'townhall', 'Alcaldía'],
  ['leisure', 'stadium', 'Estadio'],
  ['tourism', 'museum', 'Museo'],
  ['tourism', 'zoo', 'Zoológico'],
  ['tourism', 'attraction', 'Sitio de interés'],
  ['amenity', 'place_of_worship', 'Iglesia'],
  ['leisure', 'park', 'Parque'],
];

const ALIAS = ['alt_name', 'official_name', 'old_name', 'short_name', 'loc_name'];

const espera = (ms) => new Promise((r) => setTimeout(r, ms));

async function overpass(consulta) {
  for (let intento = 1; ; intento++) {
    // El servidor público corta conexiones cuando está cargado: un corte
    // se reintenta igual que un 429 o un 504.
    let fallo;
    try {
      const res = await fetch(OVERPASS, {
        method: 'POST',
        headers: { 'User-Agent': AGENTE, 'Content-Type': 'application/x-www-form-urlencoded' },
        body: 'data=' + encodeURIComponent(consulta),
      });
      if (res.ok) {
        const datos = await res.json();
        await espera(2000); // cortesía con el servidor público
        return datos;
      }
      fallo = new Error(`Overpass respondió ${res.status}`);
    } catch (e) {
      fallo = e;
    }
    if (intento >= 5) throw fallo;
    console.log(`  reintento ${intento}: ${fallo.message}`);
    await espera(15000 * intento);
  }
}

async function json(url) {
  const res = await fetch(url, { headers: { 'User-Agent': AGENTE } });
  if (!res.ok) throw new Error(`${url} respondió ${res.status}`);
  return res.json();
}

// --- Texto ---

/** Igual que `normalizar` en lib/core/lugares/texto_lugar.dart (sin abreviaturas). */
const llave = (s) =>
  s
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .toLowerCase()
    .replace(/[^a-z0-9ñ]+/g, ' ')
    .trim();

const MENORES = new Set(['de', 'del', 'la', 'las', 'los', 'el', 'y', 'e', 'en']);
const ROMANOS = /^(i|ii|iii|iv|v|vi|vii|viii|ix|x)$/;

/** «SANTO DOMINGO DE GUZMAN» → «Santo Domingo de Guzman». Sin inventar tildes. */
function deMayusculas(s) {
  return s
    .toLowerCase()
    .split(/\s+/)
    .map((p, i) => {
      if (ROMANOS.test(p)) return p.toUpperCase();
      if (i > 0 && MENORES.has(p)) return p;
      return p.charAt(0).toUpperCase() + p.slice(1);
    })
    .join(' ');
}

// --- Geometría ---

const R = 6371008.8;
const rad = (g) => (g * Math.PI) / 180;

function metros(a, b) {
  const dLat = rad(b[0] - a[0]);
  const dLon = rad(b[1] - a[1]);
  const h = Math.sin(dLat / 2) ** 2 + Math.cos(rad(a[0])) * Math.cos(rad(b[0])) * Math.sin(dLon / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(h));
}

/** Distancia de p al segmento ab, en metros, en el plano local. */
function alSegmento(p, a, b) {
  const k = Math.cos(rad(p[0]));
  const ax = (a[1] - p[1]) * k, ay = a[0] - p[0];
  const bx = (b[1] - p[1]) * k, by = b[0] - p[0];
  const dx = bx - ax, dy = by - ay;
  const l2 = dx * dx + dy * dy;
  const t = l2 === 0 ? 0 : Math.max(0, Math.min(1, -(ax * dx + ay * dy) / l2));
  const x = ax + t * dx, y = ay + t * dy;
  return Math.hypot(x, y) * (Math.PI / 180) * R;
}

/** Douglas-Peucker: quita los vértices que se apartan menos de `tol` metros. */
function simplificar(puntos, tol) {
  if (puntos.length < 3) return puntos;
  const quedan = new Uint8Array(puntos.length);
  quedan[0] = quedan[puntos.length - 1] = 1;
  const pila = [[0, puntos.length - 1]];
  while (pila.length) {
    const [i, j] = pila.pop();
    let max = 0, k = -1;
    for (let m = i + 1; m < j; m++) {
      const d = alSegmento(puntos[m], puntos[i], puntos[j]);
      if (d > max) (max = d), (k = m);
    }
    if (max > tol) {
      quedan[k] = 1;
      pila.push([i, k], [k, j]);
    }
  }
  return puntos.filter((_, i) => quedan[i]);
}

/** Une los tramos de una misma calle que comparten punta. */
function encadenar(tramos) {
  const llaveDe = (p) => p[0].toFixed(6) + ',' + p[1].toFixed(6);
  let cadenas = tramos.map((t) => t.slice());
  let cambio = true;
  while (cambio) {
    cambio = false;
    const porPunta = new Map();
    cadenas.forEach((c, i) => {
      for (const p of [c[0], c[c.length - 1]]) {
        const k = llaveDe(p);
        if (!porPunta.has(k)) porPunta.set(k, []);
        porPunta.get(k).push(i);
      }
    });
    const usado = new Set();
    const nuevas = [];
    cadenas.forEach((c, i) => {
      if (usado.has(i)) return;
      usado.add(i);
      let actual = c;
      for (;;) {
        const fin = llaveDe(actual[actual.length - 1]);
        const ini = llaveDe(actual[0]);
        const j = (porPunta.get(fin) ?? []).find((x) => !usado.has(x)) ??
          (porPunta.get(ini) ?? []).find((x) => !usado.has(x));
        if (j === undefined) break;
        usado.add(j);
        cambio = true;
        let otra = cadenas[j];
        if (llaveDe(otra[0]) === fin) actual = actual.concat(otra.slice(1));
        else if (llaveDe(otra[otra.length - 1]) === fin) actual = actual.concat(otra.slice().reverse().slice(1));
        else if (llaveDe(otra[otra.length - 1]) === ini) actual = otra.concat(actual.slice(1));
        else actual = otra.slice().reverse().concat(actual.slice(1));
      }
      nuevas.push(actual);
    });
    cadenas = nuevas;
  }
  return cadenas;
}

/** Polilínea codificada de Google, precisión 1e-5 (~1 m). */
function codificar(puntos) {
  let out = '', pLat = 0, pLon = 0;
  const num = (v) => {
    v = v < 0 ? ~(v << 1) : v << 1;
    while (v >= 0x20) {
      out += String.fromCharCode((0x20 | (v & 0x1f)) + 63);
      v >>= 5;
    }
    out += String.fromCharCode(v + 63);
  };
  for (const [lat, lon] of puntos) {
    const a = Math.round(lat * 1e5), b = Math.round(lon * 1e5);
    num(a - pLat);
    num(b - pLon);
    pLat = a;
    pLon = b;
  }
  return out;
}

const redondear = (p) => [Math.round(p[0] * 1e5) / 1e5, Math.round(p[1] * 1e5) / 1e5];

/** Un punto dentro del polígono: el centroide si cae dentro; si no, el medio
 * de la cuerda horizontal más larga a la altura del centroide. */
function puntoInterior(anillo) {
  let a = 0, cx = 0, cy = 0;
  for (let i = 0, j = anillo.length - 1; i < anillo.length; j = i++) {
    const [x0, y0] = anillo[j], [x1, y1] = anillo[i];
    const f = x0 * y1 - x1 * y0;
    a += f;
    cx += (x0 + x1) * f;
    cy += (y0 + y1) * f;
  }
  const c = [cx / (3 * a), cy / (3 * a)]; // [lon, lat]
  const xs = [];
  for (let i = 0, j = anillo.length - 1; i < anillo.length; j = i++) {
    const [x0, y0] = anillo[j], [x1, y1] = anillo[i];
    if ((y0 > c[1]) !== (y1 > c[1])) xs.push(x0 + ((c[1] - y0) / (y1 - y0)) * (x1 - x0));
  }
  xs.sort((p, q) => p - q);
  let mejor = null;
  for (let i = 0; i + 1 < xs.length; i += 2) {
    if (c[0] >= xs[i] && c[0] <= xs[i + 1]) return [c[1], c[0]];
    if (!mejor || xs[i + 1] - xs[i] > mejor[1] - mejor[0]) mejor = [xs[i], xs[i + 1]];
  }
  return mejor ? [c[1], (mejor[0] + mejor[1]) / 2] : [c[1], c[0]];
}

// --- Fuentes ---

async function areas() {
  const d = await overpass(
    `[out:json][timeout:120];relation["boundary"="administrative"]["admin_level"="6"](${CAJA});out tags;`,
  );
  const ids = new Map();
  for (const e of d.elements) if (MUNICIPIOS.includes(e.tags.name)) ids.set(e.tags.name, 3600000000 + e.id);
  for (const m of MUNICIPIOS) if (!ids.has(m)) throw new Error(`OSM no trae el municipio ${m}`);
  return { ids, fecha: d.osm3s.timestamp_osm_base };
}

function nombres(tags) {
  const alias = new Set();
  for (const k of ALIAS) for (const v of (tags[k] ?? '').split(';')) if (v.trim()) alias.add(v.trim());
  alias.delete(tags.name);
  return [...alias];
}

async function deMunicipio(nombre, area) {
  const a = `area(${area})->.m;`;
  const barrios = await overpass(
    `[out:json][timeout:180];${a}(` +
      `relation(area.m)["boundary"="administrative"]["admin_level"~"^(9|10)$"]["name"];` +
      `node(area.m)["place"~"^(neighbourhood|suburb|quarter)$"]["name"];` +
      `);out center tags;`,
  );
  const vias = await overpass(
    `[out:json][timeout:180];${a}way(area.m)["highway"~"^(${VIAS})$"]["name"];out geom tags;`,
  );
  const filtros = SITIOS.map(([k, v]) => `nwr(area.m)["${k}"="${v}"]["name"];`).join('');
  const sitios = await overpass(`[out:json][timeout:180];${a}(${filtros});out center tags;`);
  return { nombre, barrios: barrios.elements, vias: vias.elements, sitios: sitios.elements };
}

const punto = (e) => (e.type === 'node' ? [e.lat, e.lon] : e.center ? [e.center.lat, e.center.lon] : null);

function procesar(municipios) {
  const barrios = [];
  const sitios = [];
  const viasPorLlave = new Map();
  for (const { nombre: m, barrios: bs, vias, sitios: ss } of municipios) {
    // Un barrio puede venir como límite y como etiqueta: se queda uno, con
    // el punto de la etiqueta (lo pone quien mapea; el centro de la caja de
    // un límite puede caer fuera).
    const vistos = new Map();
    for (const e of bs.sort((x, y) => (x.type === 'node' ? -1 : 1) - (y.type === 'node' ? -1 : 1))) {
      const p = punto(e);
      if (!p) continue;
      const k = llave(e.tags.name);
      const previo = vistos.get(k);
      if (previo && metros(previo, p) < 1500) continue;
      vistos.set(k, p);
      const b = { n: e.tags.name, m, p: redondear(p) };
      const a = nombres(e.tags);
      if (a.length) b.a = a;
      barrios.push(b);
    }
    const sitiosVistos = new Set();
    for (const e of ss) {
      const p = punto(e);
      const tipo = SITIOS.find(([k, v]) => e.tags[k] === v);
      if (!p || !tipo) continue;
      const id = e.type + e.id;
      if (sitiosVistos.has(id)) continue;
      sitiosVistos.add(id);
      const s = { n: e.tags.name, k: tipo[2], m, p: redondear(p) };
      const a = nombres(e.tags);
      if (a.length) s.a = a;
      sitios.push(s);
    }
    for (const e of vias) {
      const k = llave(e.tags.name) + '|' + m;
      if (!viasPorLlave.has(k)) viasPorLlave.set(k, { n: e.tags.name, m, a: new Set(), tramos: [] });
      const v = viasPorLlave.get(k);
      for (const x of nombres(e.tags)) v.a.add(x);
      v.tramos.push(e.geometry.map((g) => [g.lat, g.lon]));
    }
  }
  // El mismo sitio cartografiado como nodo y como área, o repetido con el
  // mismo nombre a menos de 150 m: se queda uno.
  const sitiosUnicos = [];
  for (const s of sitios) {
    if (sitiosUnicos.some((o) => o.m === s.m && llave(o.n) === llave(s.n) && metros(o.p, s.p) < 150)) continue;
    sitiosUnicos.push(s);
  }
  const vias = [...viasPorLlave.values()].map((v) => {
    const g = encadenar(v.tramos).map((c) => codificar(simplificar(c, 6)));
    const via = { n: v.n, m: v.m, g };
    if (v.a.size) via.a = [...v.a];
    return via;
  });
  const orden = (x, y) => x.m.localeCompare(y.m) || x.n.localeCompare(y.n, 'es');
  return { barrios: barrios.sort(orden), sitios: sitiosUnicos.sort(orden), vias: vias.sort(orden) };
}

async function pot(barriosOsm) {
  const [filas, meta] = await Promise.all([json(POT_FILAS), json(POT_META)]);
  if (meta.license?.name !== 'Creative Commons Attribution | Share Alike 4.0 International') {
    throw new Error(`La licencia del POT cambió: ${meta.license?.name}`);
  }
  const enOsm = new Set(barriosOsm.filter((b) => b.m === 'Barranquilla').flatMap((b) => [b.n, ...(b.a ?? [])]).map(llave));
  const barrios = [];
  for (const f of filas) {
    if (!f.nombre || !f.the_geom) continue;
    if (enOsm.has(llave(f.nombre))) continue;
    // El anillo exterior del polígono más grande.
    const anillos = f.the_geom.coordinates.map((poli) => poli[0]);
    const anillo = anillos.sort((a, b) => b.length - a.length)[0];
    barrios.push({ n: deMayusculas(f.nombre), m: 'Barranquilla', p: redondear(puntoInterior(anillo)) });
  }
  barrios.sort((x, y) => x.n.localeCompare(y.n, 'es'));
  return {
    fuente: {
      nombre: 'Barrios de Barranquilla según POT',
      autor: meta.attribution,
      licencia: 'CC BY-SA 4.0',
      url: 'https://www.datos.gov.co/d/qui6-qeux',
      fecha: new Date(meta.rowsUpdatedAt * 1000).toISOString().slice(0, 10),
    },
    barrios,
  };
}

const { ids, fecha } = await areas();
const crudos = [];
for (const m of MUNICIPIOS) {
  console.log(`OSM: ${m}`);
  crudos.push(await deMunicipio(m, ids.get(m)));
}
const osm = procesar(crudos);
const salidaOsm = {
  fuente: {
    nombre: 'OpenStreetMap',
    autor: 'Colaboradores de OpenStreetMap',
    licencia: 'ODbL 1.0',
    url: 'https://www.openstreetmap.org/copyright',
    fecha,
  },
  ...osm,
};
const salidaPot = await pot(osm.barrios);
await writeFile(new URL('../../assets/data/lugares_osm.json', import.meta.url), JSON.stringify(salidaOsm) + '\n');
await writeFile(new URL('../../assets/data/lugares_pot.json', import.meta.url), JSON.stringify(salidaPot) + '\n');
console.log(
  `OSM ${fecha}: ${osm.barrios.length} barrios, ${osm.vias.length} vías, ${osm.sitios.length} sitios. ` +
    `POT: ${salidaPot.barrios.length} barrios que OSM no trae.`,
);
