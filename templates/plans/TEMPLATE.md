# Plan — <título corto>

## Contexto y objetivo

Qué problema resuelve y por qué ahora. Enlaces a issues o decisiones previas.

## Non-goals

Qué queda explícitamente fuera de este cambio.

## Seguridad y amenazas

- Entrada externa y validación:
- Red / SSRF / allowlist:
- Secretos y permisos:
- Ficheros y rutas:
- Dependencias nuevas:

## Pasos

1. ...
2. ...

Cada paso indica rutas o módulos concretos y qué queda fuera.

## Matriz de tests

| Criterio | Test / comando | Tipo |
|---|---|---|
| ... | `go test ./internal/... -run TestX` | unit |
| ... | `go test -race ./...` | race |
| ... | `curl` / `httptest` | integration |

## Criterios de aceptación

- [ ] ...
- [ ] ...

Cada criterio debe poder verificarse con un comando o test concreto.

## Riesgos y rollback

- Riesgo:
- Mitigación:
- Rollback:

## Evidencia

Citas `archivo:línea` del código o docs que justifican el plan.

## Run log

- Decisiones:
- Comandos ejecutados:
- Dudas abiertas (`UNRESOLVED` si aplica):
