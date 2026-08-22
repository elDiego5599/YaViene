/**
 * PhoneSimulator — la demo del teléfono, en bucle y sin interacción.
 *
 * El mockup ya no se toca: es una vitrina que se reproduce sola y vuelve a
 * empezar. Antes aceptaba clics y podía quedarse en estados raros a media
 * animación; ahora la única entrada es el tiempo, así que siempre se ve
 * como debe verse.
 *
 * Nada de lo que muestra está inventado: las rutas y sus kilómetros salen
 * de rutas.json (vía PhoneMap), el radio de aviso es el 1 km del README y
 * los textos son los mismos de la app (bus_notification_service.dart,
 * search_pill_bar.dart, eta_bottom_sheet.dart).
 */

export class PhoneSimulator {
  constructor(options = {}) {
    this.phoneEl = options.phoneEl || document.getElementById('phone');
    this.chipEl = options.chipEl || document.getElementById('phone-chip');
    this.sheetEl = options.sheetEl || document.getElementById('phone-sheet');
    this.map = options.map || null;
    this.viewEls = Array.from(document.querySelectorAll('.sheet-view'));

    this.routes = [
      { id: 'R-101', name: 'B18 Tcherassi', bus: 'B-042' },
      { id: 'R-102', name: 'C11 Silencio', bus: 'B-055' },
      { id: 'R-103', name: 'C12 Vivero Paraíso', bus: 'B-018' },
      { id: 'R-104', name: 'C13 Carrera 50 Paraíso', bus: 'B-031' },
      { id: 'R-105', name: 'C14 Carrera 54 Uninorte', bus: 'B-009' },
      { id: 'R-106', name: 'C16 Calle 72 Uninorte', bus: 'B-064' }
    ];

    this.chips = {
      locating: { icon: '◎', text: 'Localizando tu ubicación…' },
      gps: { icon: '◉', text: 'Usando tu ubicación' },
      near: { icon: '◉', text: 'Usando tu ubicación · 2 buses cerca' }
    };

    // Punto de espera: una fracción fija del recorrido. Los buses llegan a
    // él por detrás, que es como se acerca un bus de verdad a una parada.
    this.pinT = 0.62;
    this.alertRadiusMeters = 1000; // README: el aviso salta a 1 km

    // Un bus urbano va sobre los 40 km/h en corredor. A 12 m/s el número
    // de la hoja baja de a ~12 metros por segundo: se lee sin marearse.
    this.demoMetersPerSecond = 12;

    // Dónde nace cada bus, en metros por detrás del punto de espera. El
    // primero arranca justo fuera del radio de aviso para que durante la
    // demo se vea el momento en que entra.
    this.spawnMeters = [1150, 2100];
    this.paces = [1, 0.78];

    this.routeIndex = 0;
    this.timers = [];
    this.busAnimId = null;
    this.etaTimerId = null;

    this.initBusState();
    this.showView('main');
    this.play();
  }

  /* ---------- Utilidades de vista ---------- */

  showView(viewName) {
    this.viewEls.forEach(v => {
      v.classList.toggle('active', v.dataset.view === viewName);
    });
  }

  setChip(kind) {
    const config = this.chips[kind] || this.chips.locating;
    const textEl = this.chipEl && this.chipEl.querySelector('[data-el="chip-text"]');
    const iconEl = this.chipEl && this.chipEl.querySelector('[data-el="chip-icon"]');
    if (textEl) textEl.textContent = config.text;
    if (iconEl) iconEl.textContent = config.icon;
  }

  at(ms, fn) {
    this.timers.push(setTimeout(fn, ms));
  }

  clearTimers() {
    this.timers.forEach(clearTimeout);
    this.timers = [];
  }

  /* ---------- Guion ---------- */

  /**
   * Un ciclo completo: localizar, fijar el punto, elegir empresa y ruta,
   * ver los buses en vivo y activar el aviso. Al terminar se repite con la
   * siguiente ruta, así el mapa recorre las seis de Sobusa.
   */
  play() {
    this.clearTimers();
    this.stopBuses();

    this.selectedCompany = null;
    this.selectedRoute = this.routes[this.routeIndex % this.routes.length];
    this.routeIndex += 1;

    // El mapa se encuadra en la ruta de este ciclo desde el principio. El
    // punto de espera va antes que la ruta porque es lo que centra la
    // cámara: fijarlo después dejaría el encuadre en el sitio anterior.
    if (this.map) {
      this.map.setPin(this.pinT);
      this.map.setRoute(this.selectedRoute.id);
      this.map.showPin(false);
      this.map.showBuses(false);
    }

    this.resetTiles();
    this.showView('main');
    this.sheetEl.classList.add('hidden-sheet');
    this.setChip('locating');

    this.at(1300, () => {
      this.setChip('gps');
      if (this.map) this.map.showPin(true);
    });

    this.at(2600, () => {
      this.sheetEl.classList.remove('hidden-sheet');
      this.showView('main');
    });

    this.at(3800, () => this.showView('companies'));

    this.at(4900, () => {
      this.selectedCompany = 'Sobusa';
      this.updateTiles();
      this.showView('main');
    });

    this.at(6000, () => this.showView('routes'));

    this.at(7300, () => {
      this.updateTiles();
      this.showView('main');
    });

    this.at(8400, () => this.goLive());

    this.at(20000, () => {
      const btn = document.querySelector('[data-el="alert-btn"]');
      if (btn) {
        btn.classList.add('active');
        btn.textContent = 'AVISO ACTIVADO';
      }
    });

    // Cierre y vuelta a empezar.
    this.at(32000, () => this.play());
  }

  resetTiles() {
    const companyLabel = document.querySelector('[data-el="company-label"]');
    const companyBadge = document.querySelector('[data-el="company-badge"]');
    const routeLabel = document.querySelector('[data-el="route-label"]');
    const launchBtn = document.querySelector('[data-el="launch-btn"]');
    const alertBtn = document.querySelector('[data-el="alert-btn"]');

    if (companyLabel) {
      companyLabel.textContent = 'Selecciona una empresa';
      companyLabel.classList.add('muted');
    }
    if (companyBadge) {
      companyBadge.textContent = '—';
      companyBadge.classList.remove('badge-sobusa');
    }
    if (routeLabel) {
      routeLabel.textContent = 'Selecciona una ruta';
      routeLabel.classList.add('muted');
    }
    if (launchBtn) {
      launchBtn.textContent = 'Selecciona una ruta para continuar';
      launchBtn.classList.remove('ready');
    }
    if (alertBtn) {
      alertBtn.classList.remove('active');
      alertBtn.textContent = 'AVISARME CUANDO ESTÉ CERCA';
    }
  }

  updateTiles() {
    const companyLabel = document.querySelector('[data-el="company-label"]');
    const companyBadge = document.querySelector('[data-el="company-badge"]');
    const routeLabel = document.querySelector('[data-el="route-label"]');
    const launchBtn = document.querySelector('[data-el="launch-btn"]');

    if (this.selectedCompany && companyLabel && companyBadge) {
      companyLabel.textContent = this.selectedCompany;
      companyLabel.classList.remove('muted');
      companyBadge.textContent = 'SO';
      companyBadge.classList.add('badge-sobusa');
    }

    if (this.selectedCompany && routeLabel) {
      routeLabel.textContent = this.selectedRoute.name;
      routeLabel.classList.remove('muted');
    }

    if (this.selectedCompany && launchBtn) {
      launchBtn.textContent = 'Ver buses en vivo';
      launchBtn.classList.add('ready');
    }
  }

  goLive() {
    this.showView('eta');
    this.setChip('near');

    const etaRoute = document.querySelector('[data-el="eta-route"]');
    if (etaRoute) {
      etaRoute.textContent = `${this.selectedRoute.name} · ${this.selectedRoute.bus}`;
    }

    this.resetBusPositions();
    if (this.map) this.map.showBuses(true);
    this.startBuses();
  }

  /* ---------- Distancia (espeja _metricParts/_urgencyColor de eta_bottom_sheet.dart) ---------- */

  routeMeters() {
    const active = this.map && this.map.activeRoute;
    return active ? active.km * 1000 : 0;
  }

  metricParts(meters) {
    if (meters < 1000) return [Math.round(meters).toString(), 'm de ti'];
    return [(meters / 1000).toFixed(1), 'km de ti'];
  }

  urgencyColor(meters) {
    if (meters < 300) return 'var(--coral)';
    if (meters < this.alertRadiusMeters) return 'var(--warn)';
    return 'var(--green)';
  }

  nearestMeters() {
    const routeMeters = this.routeMeters();
    if (!routeMeters || !this.busState.length) return null;
    let nearest = Infinity;
    this.busState.forEach(b => {
      // Distancia sobre el recorrido, no en línea recta: el bus tiene que
      // pasar por la vía, no cruzar por encima de las manzanas.
      const gap = (this.pinT - b.t + 1) % 1;
      const meters = gap * routeMeters;
      if (meters < nearest) nearest = meters;
    });
    return Number.isFinite(nearest) ? nearest : null;
  }

  /**
   * Refresca el número una vez por segundo y redondeado a la decena. A 60
   * fps y al metro, los dígitos cambiaban tan rápido que no se leían.
   */
  updateEta() {
    const raw = this.nearestMeters();
    if (raw == null) return;

    const meters = raw < 100 ? Math.max(10, Math.round(raw)) : Math.round(raw / 10) * 10;
    const [value, unit] = this.metricParts(meters);

    const valueEl = document.querySelector('[data-el="eta-value"]');
    const unitEl = document.querySelector('.eta-unit');
    const subtitleEl = document.querySelector('.eta-subtitle');
    const barEl = document.querySelector('.eta-indicator-bar');

    if (valueEl) valueEl.textContent = value;
    if (unitEl) unitEl.textContent = unit;
    if (subtitleEl) {
      subtitleEl.textContent = meters < this.alertRadiusMeters
        ? 'Ya está dentro del radio de aviso'
        : 'Acercándose por la ruta';
    }
    if (barEl) barEl.style.background = this.urgencyColor(meters);
  }

  /* ---------- Movimiento sobre la ruta real ---------- */

  initBusState() {
    this.busState = this.spawnMeters.map((m, i) => ({
      spawnMeters: m,
      pace: this.paces[i % this.paces.length],
      t: 0
    }));
  }

  resetBusPositions() {
    const routeMeters = this.routeMeters();
    if (!routeMeters) return;
    this.busState.forEach(b => {
      b.t = (this.pinT - b.spawnMeters / routeMeters + 1) % 1;
    });
    this.pushBuses();
  }

  pushBuses() {
    if (this.map) this.map.setBuses(this.busState.map(b => b.t));
  }

  stepBuses(dt) {
    const routeMeters = this.routeMeters();
    if (!routeMeters) return;

    this.busState.forEach(b => {
      b.t = (b.t + (this.demoMetersPerSecond * b.pace * dt) / routeMeters) % 1;
      // Si ya pasó de largo el punto de espera, vuelve a su arranque:
      // siempre hay uno acercándose, como en una ruta con varios buses.
      const gap = (this.pinT - b.t + 1) % 1;
      if (gap > 0.5) b.t = (this.pinT - b.spawnMeters / routeMeters + 1) % 1;
    });

    this.pushBuses();
  }

  startBuses() {
    this.updateEta();
    if (!this.etaTimerId) {
      this.etaTimerId = setInterval(() => this.updateEta(), 1000);
    }
    if (this.busAnimId) return;

    let last = null;
    const loop = (now) => {
      const dt = last === null ? 0 : Math.min(0.1, (now - last) / 1000);
      last = now;
      this.stepBuses(dt);
      this.busAnimId = requestAnimationFrame(loop);
    };
    this.busAnimId = requestAnimationFrame(loop);
  }

  stopBuses() {
    if (this.busAnimId) {
      cancelAnimationFrame(this.busAnimId);
      this.busAnimId = null;
    }
    if (this.etaTimerId) {
      clearInterval(this.etaTimerId);
      this.etaTimerId = null;
    }
  }
}
