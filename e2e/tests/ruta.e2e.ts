// Escoger empresa y ruta y ver sus buses. Lee el backend al que apunta la
// build (BACKEND_URL); no escribe nada en él.
import { test } from '@e2e-dev/mobile';
import { expect } from 'e2e';

test.beforeEach(async ({ device, app, screen }) => {
  // La build de appPath (instalarla conserva los datos) y luego sin datos.
  await device.installApp();
  await app.clearState();
  await screen.getByRole('switch', /^He leído y acepto/).tap();
  await screen.getByRole('button', /^Ahora no/).tap();
  await screen.getByRole('button', /^Ir a la app/).tap();
});

test('el selector lista las dos empresas', async ({ screen }) => {
  await screen.getByRole('button', /^¿Qué bus esperas\?/).tap();
  await expect(screen.getByText(/Dos pasos y ves los buses moviéndose/)).toBeVisible();
  await screen.getByRole('button', /^Elegir empresa$/).tap();
  await expect(screen.getByRole('button', /^Coolitoral$/)).toBeVisible();
  await expect(screen.getByRole('button', /^Sobusa$/)).toBeVisible();
});

test('con Sobusa C11 el mapa muestra la ruta y pide el punto', async ({ screen }) => {
  await screen.getByRole('button', /^¿Qué bus esperas\?/).tap();
  await screen.getByRole('button', /^Elegir empresa$/).tap();
  await screen.getByRole('button', /^Sobusa$/).tap();
  await expect(screen.getByRole('button', /^Empresa: Sobusa/)).toBeVisible();
  await screen.getByRole('button', /^Elegir ruta$/).tap();
  await screen.getByRole('button', /^C11 Silencio/).tap();
  await screen.getByRole('button', /^Ver buses en vivo$/).tap();
  await expect(screen.getByRole('button', /^Ruta activa: C11 Silencio/)).toBeVisible();
  await expect(screen.getByText(/^Toca el mapa para indicar dónde estás/)).toBeVisible();
});

test('el menú tiene sus seis entradas', async ({ screen }) => {
  await screen.getByRole('button', /^Abrir menú/).tap();
  for (const nombre of ['Avisos', 'Ver guía de uso', 'Problemas y sugerencias', 'Privacidad', 'Términos', 'Acerca de']) {
    await expect(screen.getByRole('button', new RegExp(`^${nombre}$`))).toBeVisible();
  }
});
