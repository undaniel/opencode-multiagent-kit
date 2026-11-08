# AGENTS.md — proyecto

## Stack

- Describe aquí lenguaje, versión, gestor de paquetes y framework.
- Sin dependencias nuevas sin justificar tamaño, mantenimiento y alternativa estándar.

## Comandos

```bash
# Build
# Test
# Lint / formato
# Typecheck (si aplica)
```

Sustituye estos comentarios por los comandos reales. Sin ellos, los agentes adivinan.

## Definition of Done

1. Build, lint, typecheck y tests pasan.
2. Los tests cubren criterios de aceptación, incluidos errores.
3. No hay secretos ni `.env` en el diff.
4. Docs actualizadas si cambió CLI, API, config o env.
5. Si el proyecto arranca, la comprobación de arranque documentada en este archivo pasa.
6. Diff mínimo, sin refactors no pedidos.

## Seguridad

- Sin secretos en el repo; usa variables de entorno.
- Valida entrada externa; no confíes en headers, query ni cuerpos.
- Si haces peticiones salientes: allowlist de hosts y bloqueo de IPs privadas (SSRF).
- Limita tamaño de cuerpos/respuestas y valida `Content-Type`.
- Dependencias auditadas con la herramienta del ecosistema.

## Flujo con agentes

- Cambio de ≤2 archivos y sin superficie sensible: `build`.
- Feature/refactor/ambiguo: `orchestrator` → plan → aprobación → slices.
- No commit ni push sin pedido explícito. Conventional Commits.
