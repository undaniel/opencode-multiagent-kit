# AGENTS.md — proyecto Go

Este archivo lo leen los agentes de OpenCode. Define cómo se trabaja **en este repo**; el `AGENTS.md` global solo define el proceso.

## Stack

- Go (ver `go.mod`). Sin frameworks innecesarios; prioriza biblioteca estándar.
- Un binario si el proyecto lo permite. Frontend embebido con `embed.FS` cuando aplique.
- Sin dependencias nuevas sin justificar tamaño, mantenimiento y alternativa estándar.

## Estructura

- `cmd/<app>/main.go` — arranque y flags.
- `internal/...` — lógica de negocio y paquetes no exportados.
- `web/` — estáticos embebidos.
- `docs/` — decisiones y documentación.
- Tests junto al paquete (`*_test.go`).

## Comandos

```bash
gofmt -l .                     # debe salir vacío
go vet ./...
go build ./...
go test ./...
go test -race ./...
golangci-lint run              # si está instalado
govulncheck ./...              # si está instalado
```

## Definition of Done

Una tarea no está terminada hasta que:

1. `gofmt`, `go vet`, `go build` y `go test` pasan.
2. Los tests nuevos cubren los criterios de aceptación; los casos de error también.
3. `go test -race ./...` pasa si se tocó concurrencia o HTTP.
4. No hay secretos, `.env`, tokens ni artefactos de debug en el diff.
5. La documentación de usuario cambió si cambió CLI, config, env o API.
6. La app arranca y responde: `bash .opencode/smoke.sh` pasa.
7. El diff es mínimo y no incluye refactors no pedidos.

## Convenciones Go

- Errores envueltos con `%w` y contexto (`fmt.Errorf("fetch cat: %w", err)`).
- `context.Context` como primer parámetro en I/O; nunca `context.Background()` dentro de handlers.
- Timeouts explícitos en clientes y servidores; sin `http.DefaultClient` en producción.
- Cierra bodies y usa `defer`; limita tamaño de respuestas externas.
- Logs estructurados (`log/slog`), sin datos personales ni secretos.
- Graceful shutdown con `signal.NotifyContext` y `Server.Shutdown`.
- Tablas de tests para lógica pura; `httptest` para handlers.
- No `panic` en rutas de request; devuelve errores.

## Seguridad

- Valida toda entrada externa; no confíes en headers, query ni cuerpo.
- Si el servidor hace peticiones salientes, usa allowlist de hosts y prohíbe IPs privadas (SSRF).
- Limita tamaño de imágenes/respuestas y valida `Content-Type`; evita descomprimir sin límite.
- Caché acotada (LRU/TTL); nada de mapas sin límite alimentados por el usuario.
- Cabeceras: `Content-Security-Policy`, `X-Content-Type-Options: nosniff`, `Referrer-Policy`.
- Sin secretos en el repo; usa variables de entorno o el gestor del despliegue.

## Flujo con agentes

- Cambio de ≤2 archivos y sin superficie sensible: agente `build`.
- Feature, refactor o cambio ambiguo: `orchestrator` → plan → aprobación → slices.
- Tests/lint antes de pedir review; el review no sustituye la verificación.
- No hacer commit ni push sin pedido explícito.
- Commits en Conventional Commits (`feat:`, `fix:`, `test:`, `docs:`, `refactor:`).

## Decisiones

- Cambios de arquitectura o dependencias: deja una nota corta en `docs/decisions/`.
- Si algo queda pendiente, anótalo con `shortcut: <límite>, <cuándo mejorarlo>`.
