# YaViene — CLAUDE

Este proyecto usa las skills de `mattpocock/skills` para estandarizar el flujo con Claude.

## Skills activas
- `grill-me` — interroga casos borde antes de codear. Invoca con `/grill-me` al planificar una feature grande.
- `to-spec` / `to-tickets` — planifica features complejas (spec → tickets).
- `code-review` — audita calidad y rendimiento.

## Flujo
1. Para feature grande de **YA VIENE**, inicia con `/grill-me`.
2. Luego usa `to-spec` y `to-tickets` para planificar.
3. Implementa y cierra con `code-review`.

Skills instaladas en `.claude/skills/` (copia de `mattpocock/skills`). Ver `npx skills list` para todas.
