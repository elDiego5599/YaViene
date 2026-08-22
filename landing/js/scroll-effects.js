/**
 * ScrollEffects — aparición de las secciones al entrar en pantalla.
 *
 * La demo del teléfono ya no vive aquí: se reproduce sola en bucle desde
 * PhoneSimulator, sin depender del scroll ni del cursor.
 */

export class ScrollEffects {
  constructor() {
    this.reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    this.initScrollReveal();
  }

  initScrollReveal() {
    const revealEls = document.querySelectorAll('.reveal');
    if (!revealEls.length) return;

    if (this.reduceMotion) {
      revealEls.forEach(el => el.classList.add('is-visible'));
      return;
    }

    const observer = new IntersectionObserver((entries) => {
      entries.forEach(entry => {
        if (entry.isIntersecting) {
          const el = entry.target;
          const delay = el.dataset.revealDelay || 0;
          el.style.transitionDelay = `${delay}ms`;
          el.classList.add('is-visible');
          observer.unobserve(el);
        }
      });
    }, { threshold: 0.15 });

    revealEls.forEach(el => observer.observe(el));
  }
}
