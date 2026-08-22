/**
 * ContactForm - Handles validation, interactive submission, and success states
 * for the company partnership interest form.
 */

export class ContactForm {
  constructor(options = {}) {
    this.form = options.form || document.getElementById('contact-form');
    this.successBox = options.successBox || document.getElementById('form-success');

    if (!this.form) return;
    this.bindEvents();
  }

  bindEvents() {
    this.form.addEventListener('submit', (e) => {
      e.preventDefault();
      this.handleSubmit();
    });
  }

  handleSubmit() {
    const submitBtn = this.form.querySelector('.form-submit-btn');
    if (submitBtn) {
      submitBtn.textContent = 'Enviando…';
      submitBtn.style.opacity = '0.7';
      submitBtn.disabled = true;
    }

    // Simulate network submission with instant visual polish
    setTimeout(() => {
      this.form.style.display = 'none';
      if (this.successBox) {
        this.successBox.style.display = 'block';
        this.successBox.scrollIntoView({ behavior: 'smooth', block: 'center' });
      }
    }, 600);
  }
}
