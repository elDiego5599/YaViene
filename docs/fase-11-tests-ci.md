# Ya Viene: Fase 11, tests automatizados y CI

Fecha: 2026-08-04
Estado: implementada

## Tests Backend

Se agrego `tests/security.test.ts` con pruebas de:

- Hash y verificacion de PIN.
- JWT canonico y deteccion de tampering.
- Rate limiter.

Nuevo comando:

```bash
npm test
```

## Tests Dart

Se agrego:

```text
ya_viene_core/test/bus_position_test.dart
```

Verifica:

- Timestamp epoch.
- Ghost canonico.
- Sequence.
- Serializacion `isGhost`.

## CI Repositorio Principal

Archivo:

```text
.github/workflows/ci.yml
```

Ejecuta:

- `flutter pub get` y analyzer/test del core.
- Analyzer/test del conductor.
- Analyzer del pasajero.

## CI Backend

Archivo:

```text
YaVieneBackend/.github/workflows/ci.yml
```

Ejecuta:

- Node.js 22.
- `npm ci`.
- `npm run build`.
- `npm test`.

## Validacion Local

- Backend `npm run build`: PASS.
- Backend `npm test`: 3/3 PASS.
- Conductor analyzer: PASS.
- Conductor tests: PASS.
- Pasajero analyzer: PASS.
- Core analyzer: PASS.
- Core test: PASS.
- Load test: PASS.

## Limitaciones

- CI aun no ejecuta pruebas E2E con broker y SQLite real.
- CI aun no ejecuta carga por costo de recursos.
- No se configura un servicio de coverage.
- `npm audit` sigue pendiente de resolver las vulnerabilidades existentes.

## Criterio De Salida

La fase queda implementada porque los contratos criticos tienen tests
automatizados y cada repositorio tiene un workflow reproducible para impedir
regresiones basicas.
