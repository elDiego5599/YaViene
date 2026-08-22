/**
 * Main Application Bootstrap - YaViene Landing Page
 */

import { PhoneMap } from './phone-map.js';
import { PhoneSimulator } from './phone-simulator.js';
import { ScrollEffects } from './scroll-effects.js';
import { ContactForm } from './contact-form.js';

document.addEventListener('DOMContentLoaded', () => {
  // Mapa del mockup: las seis rutas reales de Sobusa.
  const map = new PhoneMap();

  // La demo del teléfono: arranca sola y se repite.
  new PhoneSimulator({ map });

  // Apariciones al hacer scroll.
  new ScrollEffects();

  // Initialize Contact Form
  new ContactForm();
});
