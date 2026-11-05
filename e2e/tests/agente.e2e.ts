// Pasos en lenguaje natural con GitHub Copilot. Sin `npx e2e login
// github-copilot` no hay modelo y se saltan.
import { existsSync } from 'node:fs';
import { homedir } from 'node:os';
import { join } from 'node:path';
import { test } from '@e2e-dev/mobile';

const sesion = join(process.env.XDG_CONFIG_HOME || join(homedir(), '.config'), 'e2e', 'oauth.json');
const sinModelo = existsSync(sesion) ? false : 'sin `npx e2e login github-copilot`';

test('un pasajero nuevo escoge su ruta y pone su punto', { skip: sinModelo }, async ({ agent, app, device }) => {
  await device.installApp();
  await app.clearState();
  await agent.act('acepta privacidad y términos, sigue sin ubicación y entra a la app sin ver la guía');
  await agent.act('escoge la empresa Sobusa y la ruta C11 Silencio y abre los buses en vivo');
  await agent.act('toca el centro del mapa para poner el punto de espera');
  await agent.assert('el mapa muestra la ruta C11 Silencio activa y ya no pide tocar el mapa donde tomas tu bus');
});
