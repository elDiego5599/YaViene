// Pruebas E2E de la app del pasajero en el simulador de iOS, con
// tester-army/e2e. Las deterministas (screen + expect) no llaman a ningún
// modelo; las de agente usan GitHub Copilot y se saltan sin `npx e2e login
// github-copilot` (ver tests/agente.e2e.ts).
import type { E2EConfig } from 'e2e';
import { copilot } from 'e2e/oauth/copilot';
import { mobile } from '@e2e-dev/mobile';
import { mobileTools } from '@e2e-dev/mobile/tools';

// Con varios simuladores encendidos hay que nombrar uno; E2E_DEVICE lo
// cambia sin tocar el archivo.
const iphone = mobile({ platform: 'ios', device: process.env.E2E_DEVICE ?? 'iPhone 17' });

export default {
  targets: [
    {
      name: 'ios',
      engine: iphone,
      app: {
        bundleId: 'com.yaviene.yaviene',
        // La build del simulador: `flutter build ios --simulator
        // --dart-define=BACKEND_URL=...` en app_pasajero.
        appPath: '../app_pasajero/build/ios/iphonesimulator/Runner.app',
        // Sin ubicación: la alerta del sistema no tapa la app y el punto de
        // espera se pone tocando el mapa, como sin GPS. Los avisos no se
        // pueden fijar en este simulador (simctl privacy no los cubre).
        permissions: { location: 'deny' },
      },
    },
  ],
  workers: 1,
  timeout: 180_000,
  assertionTimeout: 15_000,
  agents: {
    default: {
      model: copilot('claude-sonnet-5'),
      tools: mobileTools(iphone),
      context: [
        'Ya Viene es una app de Barranquilla para ver en vivo los buses de una ruta y a qué distancia vienen (distancia, nunca tiempo de llegada).',
        'Primera vez: bienvenida con un interruptor «He leído y acepto la privacidad y los términos de uso»; hasta aceptarlo, «Permitir ubicación» y «Ahora no» no responden. Luego un diálogo «Bienvenido» con «Ver la guía» o «Ir a la app».',
        'En el mapa, «¿Qué bus esperas?» abre «Elige tu ruta»: primero «Elegir empresa» (Coolitoral, Sobusa), luego «Elegir ruta» y «Ver buses en vivo».',
        'Sin GPS, el punto de espera se pone tocando el mapa. El menú («Abrir menú») tiene Avisos, Ver guía de uso, Problemas y sugerencias, Privacidad, Términos y Acerca de.',
      ].join('\n'),
    },
  },
} satisfies E2EConfig;
