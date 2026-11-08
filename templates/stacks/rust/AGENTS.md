# AGENTS.md — proyecto Rust

## Stack

- Rust stable salvo que el repo fije un toolchain.
- Sin dependencias nuevas sin justificar tamaño, mantenimiento y alternativa estándar.
- Formato con `rustfmt`; lint con `clippy -D warnings`.

## Comandos

```bash
cargo fmt --check
cargo clippy --all-targets -- -D warnings
cargo test
cargo build
cargo audit            # si está instalado
```

## Definition of Done

1. `cargo fmt --check` y `clippy -D warnings` pasan.
2. `cargo test` pasa y cubre criterios de aceptación, incluidos errores.
3. No hay secretos ni `.env` en el diff.
4. Docs actualizadas si cambió CLI, API, config o env.
5. `bash .opencode/smoke.sh` pasa (build, tests y arranque).
6. Diff mínimo, sin refactors no pedidos.

## Convenciones

- Errores con `thiserror`/`anyhow` según el crate; no `unwrap()` en rutas de request.
- `?` para propagar; añade contexto cuando el error se cruce de capa.
- Evita `clone()` innecesario; usa préstamos y `Cow` cuando aplique.
- Tests unitarios en el módulo e integración en `tests/`.
- Async: timeouts en clientes y cancelación cooperativa.

## Seguridad

- Sin secretos en el repo; usa variables de entorno.
- Valida entrada externa; no confíes en headers, query ni cuerpos.
- Si haces peticiones salientes: allowlist de hosts y bloqueo de IPs privadas (SSRF).
- Limita tamaño de cuerpos/respuestas y valida `Content-Type`.
- Dependencias auditadas con `cargo audit`.

## Flujo con agentes

- Cambio de ≤2 archivos y sin superficie sensible: `build`.
- Feature/refactor/ambiguo: `orchestrator` → plan → aprobación → slices.
- No commit ni push sin pedido explícito. Conventional Commits.
