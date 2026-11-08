# AGENTS.md — proyecto Node/TypeScript

## Stack

- Node.js LTS. TypeScript si existe `tsconfig.json`.
- Sin dependencias nuevas sin justificar tamaño, mantenimiento y alternativa nativa.
- El gestor de paquetes lo dicta el lockfile: `package-lock.json`, `pnpm-lock.yaml`, `yarn.lock` o `bun.lock*`.

## Comandos

```bash
npm ci                 # o pnpm/yarn/bun install --frozen-lockfile
npm run lint --if-present
npx tsc --noEmit       # si hay tsconfig.json
npm test --if-present
npm run build --if-present
npm audit --audit-level=high
```

## Definition of Done

1. Lint, typecheck, tests y build pasan.
2. Los tests cubren los criterios de aceptación, incluidos errores.
3. No hay secretos ni `.env` en el diff.
4. Docs actualizadas si cambió CLI, API, config o env.
5. La app arranca y responde: `bash .opencode/smoke.sh` pasa.
6. Diff mínimo, sin refactors no pedidos.

## Convenciones

- `strict` en TypeScript; evita `any` sin justificar.
- Errores con contexto; no silencies promesas rechazadas.
- Valida entrada externa con zod/valibot o validación manual explícita.
- No uses `fetch` sin timeout (`AbortSignal.timeout`).
- Tests con el runner del proyecto (Vitest/Jest/Node test); integración con `supertest` o `fetch` contra un servidor efímero.

## Seguridad

- Sin secretos en el repo; usa variables de entorno.
- Si hay peticiones salientes, allowlist de hosts y bloqueo de IPs privadas (SSRF).
- Limita tamaño de cuerpos y respuestas; valida `Content-Type`.
- Dependencias auditadas; no instales paquetes abandonados.
- Cabeceras de seguridad si sirves HTML.

## Flujo con agentes

- Cambio de ≤2 archivos y sin superficie sensible: `build`.
- Feature/refactor/ambiguo: `orchestrator` → plan → aprobación → slices.
- No commit ni push sin pedido explícito. Conventional Commits.
