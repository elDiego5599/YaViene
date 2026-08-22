/**
 * PhoneMap — el mapa del mockup, con el mismo material que ve el pasajero.
 *
 * El fondo es un mosaico real de Barranquilla en CARTO Voyager, el mismo
 * estilo que carga map_widget.dart, y encima va la polilínea azul de la
 * ruta activa con los waypoints reales de rutas.json. Los generó
 * scripts/gen_mapa_landing.py, así que fondo y trazado comparten el
 * encuadre Web Mercator: la ruta cae sobre las calles que le tocan.
 *
 * Todo vive en el espacio de usuario del SVG: el pin y los buses son
 * elementos SVG, no divs colocados en porcentajes. Antes se convertía de
 * coordenadas SVG a píxeles de pantalla con getScreenCTM(), y como esa
 * matriz cambia al hacer scroll, los marcadores se iban a la deriva.
 */

import { YV_RUTAS } from '../assets/data/rutas-landing.js';

const SVG_NS = 'http://www.w3.org/2000/svg';
const XLINK = 'http://www.w3.org/1999/xlink';

/** Aire alrededor de la ruta al encuadrarla, como fracción de su tamaño. */
const FIT_PAD = 0.12;

/**
 * Alto máximo del encuadre, en píxeles del mosaico. A esta escala (z13,
 * ~9,4 m por píxel) son unos 5,8 km de ciudad: se ve el barrio alrededor
 * del punto de espera y los buses se notan avanzar.
 */
const VISTA_MAX = 620;

/** Tamaño en píxeles de pantalla de los marcadores, a cualquier zoom. */
const BUS_PX = 26;
const PIN_PX = 34;

export class PhoneMap {
  constructor(options = {}) {
    this.svgEl = options.svgEl || document.getElementById('phone-routes');
    this.mapEl = options.mapEl || document.getElementById('phone-map');
    this.rutas = YV_RUTAS.rutas;
    this.mapa = YV_RUTAS.mapa;
    this.activeRoute = this.rutas[0];
    this.busNodes = [];

    if (!this.svgEl || !this.mapEl) return;

    this.build();
    this.setRoute(this.activeRoute.id);

    this._onResize = () => this.fitToRoute();
    window.addEventListener('resize', this._onResize, { passive: true });
  }

  /* ---------- Construcción ---------- */

  build() {
    const [, , w, h] = YV_RUTAS.viewBox;
    this.canvas = { w, h };
    this.svgEl.replaceChildren();
    this.svgEl.setAttribute('preserveAspectRatio', 'xMidYMid slice');

    const defs = document.createElementNS(SVG_NS, 'defs');
    defs.innerHTML = `
      <linearGradient id="busBody" x1="0" y1="0" x2="0" y2="1">
        <stop offset="0%" stop-color="#EF978E"/>
        <stop offset="100%" stop-color="#E86A5E"/>
      </linearGradient>
      <clipPath id="busClip">
        <rect x="-16" y="-30" width="32" height="60" rx="16"/>
      </clipPath>
      <linearGradient id="pinGrad" x1="0" y1="0" x2="0" y2="1">
        <stop offset="0%" stop-color="#4ADE80"/>
        <stop offset="100%" stop-color="#059669"/>
      </linearGradient>`;
    this.svgEl.appendChild(defs);

    // La ruta del mosaico viene relativa al archivo de datos, pero un href
    // dentro del SVG se resolvería contra la URL del documento. Se ancla al
    // módulo de datos para que dé igual desde qué página se incluya.
    const baseDatos = new URL('../assets/data/', import.meta.url);
    const src = new URL(this.mapa.src, baseDatos).href;

    const img = document.createElementNS(SVG_NS, 'image');
    img.setAttribute('href', src);
    // href basta en navegadores actuales; xlink:href es el respaldo.
    img.setAttributeNS(XLINK, 'xlink:href', src);
    img.setAttribute('x', 0);
    img.setAttribute('y', 0);
    img.setAttribute('width', w);
    img.setAttribute('height', h);
    this.svgEl.appendChild(img);

    // Ruta activa: orla blanca abajo, azul encima — las dos capas que
    // apila map_widget.dart sobre MapLibre.
    this.casingEl = document.createElementNS(SVG_NS, 'path');
    this.casingEl.setAttribute('class', 'map-route-casing');
    this.svgEl.appendChild(this.casingEl);

    this.activeEl = document.createElementNS(SVG_NS, 'path');
    this.activeEl.setAttribute('class', 'map-route-active');
    this.svgEl.appendChild(this.activeEl);

    this.terminalsEl = document.createElementNS(SVG_NS, 'g');
    this.terminalsEl.setAttribute('class', 'map-terminals');
    this.svgEl.appendChild(this.terminalsEl);

    this.markersEl = document.createElementNS(SVG_NS, 'g');
    this.markersEl.setAttribute('class', 'map-markers');
    this.svgEl.appendChild(this.markersEl);

    this.pinNode = this.makePin();
    this.markersEl.appendChild(this.pinNode);
  }

  /** Cápsula roja: la misma geometría que createFlatTransitMarker(). */
  makeBus() {
    const g = document.createElementNS(SVG_NS, 'g');
    g.setAttribute('class', 'map-bus');
    g.innerHTML = `
      <g class="map-bus-art">
        <rect x="-16" y="-30" width="32" height="60" rx="16" fill="url(#busBody)"/>
        <ellipse cx="0" cy="-15.6" rx="11.5" ry="7.8" fill="#FFFFFF" opacity="0.3"
                 clip-path="url(#busClip)"/>
        <rect x="-16" y="-30" width="32" height="60" rx="16" fill="none"
              stroke="#FFFFFF" stroke-width="2.6" stroke-opacity="0.92"/>
      </g>`;
    return g;
  }

  /** Gota verde de assets/icons/pin.svg, anclada en la punta. */
  makePin() {
    const g = document.createElementNS(SVG_NS, 'g');
    g.setAttribute('class', 'map-pin');
    g.innerHTML = `
      <g class="map-pin-art" transform="translate(-40 -76)">
        <circle class="map-pin-ping" cx="40" cy="76" r="10" fill="var(--green)"/>
        <path d="M40 76 Q10 48 14 30 A26 26 0 1 1 66 30 Q70 48 40 76 Z" fill="url(#pinGrad)"/>
        <circle cx="40" cy="30" r="12.5" fill="#FFFFFF"/>
        <circle cx="40" cy="30" r="8.5" fill="#047857"/>
      </g>`;
    return g;
  }

  /* ---------- Encuadre ---------- */

  /**
   * Encuadra la ruta activa en la pantalla del teléfono. El viewBox se
   * ajusta a la proporción real del hueco para que el mapa no se deforme,
   * igual que cuando la app recentra la cámara al elegir ruta.
   */
  fitToRoute() {
    const box = this.bboxOf(this.activeRoute);
    if (!box) return;

    const rect = this.mapEl.getBoundingClientRect();
    const aspect = rect.height > 0 ? rect.width / rect.height : 0.5;

    let w = box.w * (1 + FIT_PAD * 2);
    let h = box.h * (1 + FIT_PAD * 2);
    // Se agranda el lado que falte hasta cuadrar con la pantalla, para que
    // el mapa no salga deformado.
    if (w / h < aspect) w = h * aspect;
    else h = w / aspect;

    // Dos topes. Uno: nunca alejarse más de VISTA_MAX, o la ruta entera
    // cabría pero los buses serían puntos que no se ven moverse. Dos:
    // nunca salirse del mosaico, o quedarían franjas vacías a los lados.
    const fit = Math.min(1, VISTA_MAX / h, this.canvas.w / w, this.canvas.h / h);
    w *= fit;
    h *= fit;

    // El encuadre se centra en el punto de espera, que es donde pasa todo;
    // si aún no hay punto, en el centro de la ruta.
    const foco = this.pinT != null ? this.pointAt(this.pinT) : null;
    const cx = foco ? foco.x : box.x + box.w / 2;
    const cy = foco ? foco.y : box.y + box.h / 2;
    const clamp = (v, max) => Math.max(0, Math.min(max, v));
    this.view = {
      x: clamp(cx - w / 2, this.canvas.w - w),
      y: clamp(cy - h / 2, this.canvas.h - h),
      w,
      h
    };
    this.svgEl.setAttribute('viewBox', `${this.view.x} ${this.view.y} ${w} ${h}`);

    // Unidades de usuario por píxel de pantalla: con esto los marcadores
    // conservan su tamaño aparente a cualquier zoom.
    this.unitsPerPx = rect.width > 0 ? w / rect.width : 1;
    this.scaleMarkers();
  }

  bboxOf(route) {
    if (!route) return null;
    const nums = route.d.slice(1).split(' L');
    let minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity;
    nums.forEach(pair => {
      const [x, y] = pair.split(' ').map(Number);
      if (x < minX) minX = x;
      if (x > maxX) maxX = x;
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;
    });
    if (!Number.isFinite(minX)) return null;
    return { x: minX, y: minY, w: maxX - minX || 1, h: maxY - minY || 1 };
  }

  scaleMarkers() {
    const u = this.unitsPerPx || 1;
    // La cápsula mide 60 unidades de alto en su dibujo original.
    this.busScale = (BUS_PX * u) / 60;
    this.pinScale = (PIN_PX * u) / 76;
    this.redrawMarkers();
  }

  /* ---------- Ruta activa ---------- */

  setRoute(routeId) {
    const route = this.rutas.find(r => r.id === routeId);
    if (!route || !this.activeEl) return;
    this.activeRoute = route;

    this.casingEl.setAttribute('d', route.d);
    this.activeEl.setAttribute('d', route.d);
    this._length = this.activeEl.getTotalLength();

    this.terminalsEl.replaceChildren();
    route.extremos.forEach(([x, y]) => {
      const c = document.createElementNS(SVG_NS, 'circle');
      c.setAttribute('cx', x);
      c.setAttribute('cy', y);
      c.setAttribute('r', 9);
      this.terminalsEl.appendChild(c);
    });

    this.fitToRoute();
  }

  routeByName(name) {
    return this.rutas.find(r => r.nombre === name) || null;
  }

  /** Punto en unidades del SVG. t: 0 = terminal A, 1 = terminal B. */
  pointAt(t) {
    if (!this.activeEl || !this._length) return null;
    const clamped = Math.max(0, Math.min(1, t));
    return this.activeEl.getPointAtLength(clamped * this._length);
  }

  /** Rumbo en grados, midiendo un tramo corto hacia adelante. */
  headingAt(t) {
    if (!this._length) return 0;
    const step = Math.min(0.004, 12 / this._length);
    const a = this.pointAt(t);
    const b = this.pointAt(Math.min(1, t + step)) || a;
    if (!a || !b) return 0;
    const dx = b.x - a.x;
    const dy = b.y - a.y;
    if (dx === 0 && dy === 0) return 0;
    // La cápsula apunta hacia -y en reposo.
    return (Math.atan2(dx, -dy) * 180) / Math.PI;
  }

  /* ---------- Marcadores ---------- */

  setPin(t) {
    this.pinT = t;
    this.drawPin();
  }

  drawPin() {
    if (!this.pinNode || this.pinT == null) return;
    const p = this.pointAt(this.pinT);
    if (!p) return;
    const s = this.pinScale || 1;
    this.pinNode.setAttribute('transform', `translate(${p.x} ${p.y}) scale(${s})`);
  }

  /** Coloca tantos buses como valores de t reciba, orientados a su rumbo. */
  setBuses(ts) {
    this.busTs = ts;
    while (this.busNodes.length < ts.length) {
      const node = this.makeBus();
      // Debajo del pin: el pin es del usuario y manda.
      this.markersEl.insertBefore(node, this.pinNode);
      this.busNodes.push(node);
    }
    this.busNodes.forEach((node, i) => {
      node.style.display = i < ts.length ? '' : 'none';
    });
    this.drawBuses();
  }

  drawBuses() {
    if (!this.busTs) return;
    const s = this.busScale || 1;
    this.busTs.forEach((t, i) => {
      const node = this.busNodes[i];
      if (!node) return;
      const p = this.pointAt(t);
      if (!p) return;
      const deg = this.headingAt(t);
      node.setAttribute(
        'transform',
        `translate(${p.x} ${p.y}) rotate(${deg.toFixed(1)}) scale(${s})`
      );
    });
  }

  redrawMarkers() {
    this.drawPin();
    this.drawBuses();
  }

  showPin(on) {
    if (this.pinNode) this.pinNode.classList.toggle('is-on', !!on);
  }

  showBuses(on) {
    this.busNodes.forEach(n => n.classList.toggle('is-on', !!on));
  }
}
