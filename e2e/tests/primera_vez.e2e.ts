// La primera vez que se abre la app: sin aceptar privacidad y términos no se
// sigue, y aceptándolos se llega al mapa. Sin modelo: solo screen y expect.
import { test } from '@e2e-dev/mobile';
import { expect } from 'e2e';

test.beforeEach(async ({ device, app }) => {
  // La build de appPath (instalarla conserva los datos) y luego sin datos.
  await device.installApp();
  // Borra los datos: la app vuelve a la bienvenida.
  await app.clearState();
});

test('la bienvenida no deja seguir hasta aceptar', async ({ screen }) => {
  await expect(screen.getByText(/Tu ciudad en vivo/)).toBeVisible();
  await expect(screen.getByRole('button', /^Permitir ubicación/)).toBeDisabled();
  await expect(screen.getByRole('button', /^Ahora no/)).toBeDisabled();
  await screen.getByRole('switch', /^He leído y acepto/).tap();
  await expect(screen.getByRole('button', /^Permitir ubicación/)).toBeEnabled();
  await expect(screen.getByRole('button', /^Ahora no/)).toBeEnabled();
});

test('aceptando y sin ubicación se llega al mapa', async ({ screen }) => {
  await screen.getByRole('switch', /^He leído y acepto/).tap();
  await screen.getByRole('button', /^Ahora no/).tap();
  await expect(screen.getByText(/¿Te mostramos cómo funciona\?/)).toBeVisible();
  await screen.getByRole('button', /^Ir a la app/).tap();
  await expect(screen.getByRole('button', /^¿Qué bus esperas\?/)).toBeVisible();
  // El permiso viene negado (e2e.config.ts): la app lo dice y ofrece Ajustes.
  await expect(screen.getByRole('button', /^Ubicación bloqueada\. Abrir/)).toBeVisible();
  await expect(screen.getByText(/^Toca el mapa donde tomas tu bus/)).toBeVisible();
});
