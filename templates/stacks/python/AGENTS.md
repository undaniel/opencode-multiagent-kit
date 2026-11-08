# AGENTS.md — proyecto Python

## Stack

- Python 3.11+ salvo que el repo fije otra versión.
- Sin dependencias nuevas sin justificar tamaño, mantenimiento y alternativa estándar.
- Formato y lint con `ruff`; tipos con `mypy` si el repo lo configura.

## Comandos

```bash
ruff check .
ruff format --check .
mypy .                 # si hay configuración de mypy
pytest
pip-audit
```

## Definition of Done

1. `ruff check` y `ruff format --check` pasan.
2. `pytest` pasa y cubre criterios de aceptación, incluidos errores.
3. `mypy` pasa si el proyecto lo tiene configurado.
4. No hay secretos ni `.env` en el diff.
5. Docs actualizadas si cambió CLI, API, config o env.
6. La app arranca y responde: `bash .opencode/smoke.sh` pasa.

## Convenciones

- Type hints en APIs públicas; evita `Any` sin justificar.
- Errores con contexto; no uses `except Exception: pass`.
- `pathlib` para rutas; encoding explícito al abrir ficheros.
- Context managers para recursos; timeouts en clientes HTTP.
- Tests con `pytest`; fixtures para I/O y `tmp_path` para ficheros.
- No `print` para logs; usa `logging` o `structlog`.

## Seguridad

- Sin secretos en el repo; usa variables de entorno o el gestor del despliegue.
- Valida entrada externa; no confíes en query, headers ni cuerpos.
- Si haces peticiones salientes: allowlist de hosts, timeout y bloqueo de IPs privadas (SSRF).
- No uses `pickle`, `eval` ni `yaml.load` sin `SafeLoader` con datos externos.
- Dependencias auditadas con `pip-audit`.

## Flujo con agentes

- Cambio de ≤2 archivos y sin superficie sensible: `build`.
- Feature/refactor/ambiguo: `orchestrator` → plan → aprobación → slices.
- No commit ni push sin pedido explícito. Conventional Commits.
