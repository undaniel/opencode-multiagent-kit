# Kit multiagente para OpenCode (DeepSeek)

Monta un equipo de agentes reutilizable en **cualquier proyecto**: un orquestador que planifica, delega, revisa y audita, más las skills de método de Superpowers.

Probado con **OpenCode 2.2.6** y **DeepSeek V4 Pro/Flash**. Los agentes y skills son prompts: funcionan con cualquier proveedor; solo hay que cambiar los IDs de modelo.

## Qué instala

| Rol | Agentes |
|---|---|
| Orquestador | `orchestrator` (no lee ni escribe código: delega) |
| Analista / plan | `plan-runner`, `spec-critic`, `api-docs-researcher` |
| Dev | `code-executor` (implementa), `code-explorer` (solo lectura) |
| QA | `test-verifier`, `code-reviewer`, `docs-reviewer` |
| Seguridad | `security-reviewer`, `host-security-investigator` |

Flujo con orquestador:

1. `orchestrator` recibe la petición.
2. `plan-runner` escribe un plan en `.opencode/plans/` del proyecto.
3. El plan se aprueba o se revisa (pregunta `PlanApprove`).
4. `code-executor` implementa por slices acotados.
5. `test-verifier`, `code-reviewer`, `security-reviewer` y `docs-reviewer` validan.

El agente por defecto es **`build`** (rápido, para cambios pequeños). El orquestador se usa explícitamente para trabajo no trivial.

Superpowers añade el método: `brainstorming`, `writing-plans`, `test-driven-development`, `systematic-debugging`, `requesting-code-review`, `verification-before-completion`, `subagent-driven-development`, entre otras.

## Inicio rápido

Proyecto nuevo desde cero (esqueleto que compila, tests, hook, CI y smoke):

```bash
bash init-project.sh --new ~/proyectos/mi-app --stack go
cd ~/proyectos/mi-app
bash .opencode/smoke.sh
opencode --agent orchestrator
```

Proyecto que ya existe (solo añade los gates):

```bash
bash init-project.sh ~/proyectos/mi-app
cd ~/proyectos/mi-app
opencode
```

Abre con `build` para cambios pequeños. Para una feature, refactor o bug ambiguo:

```bash
opencode --agent orchestrator
```

El orquestador escribe un plan en `.opencode/plans/`, pide aprobación y recién entonces delega la implementación.

Si aún no está instalado, ejecuta el instalador de tu sistema (ver **Instalación**).

## Requisitos

- **OpenCode 2.x** (`opencode --version`). En V1 cambia `plugins` por `plugin` en la config.
- **Linux/macOS/WSL:** `git`, `python3`, `npm` y `node` en el PATH.
- **Windows nativo:** PowerShell 5.1 o superior, `git`, `npm` y `node` en el PATH (no hace falta Python).
- Para los gates del proyecto, la toolchain de tu stack en el PATH: Go, Node, Python, Rust o Java. Los hooks omiten las herramientas opcionales que no estén instaladas.
- Un proveedor configurado en OpenCode. Para DeepSeek: `opencode auth login` (o la variable de entorno de tu proveedor) y comprobar con `opencode models | grep deepseek`.
- Modelos disponibles. Por defecto el kit usa un esquema híbrido:
  - `deepseek/deepseek-v4-pro`: `orchestrator`, `plan`, `plan-runner`, `code-reviewer`, `security-reviewer`, `spec-critic`.
  - `deepseek/deepseek-flash`: `build`, exploración, ejecución, verificación y docs.

Si tus IDs son distintos, pásalos al instalador (ver abajo).

## Windows 11

Funciona en los dos modos: OpenCode corre nativo en Windows y el kit es solo texto. Hay un instalador por plataforma.

**Recomendado: WSL 2** (lo que documenta OpenCode).

```powershell
wsl --install
```

Dentro de Ubuntu:

```bash
sudo apt update && sudo apt install -y git python3 npm
curl -fsSL https://opencode.ai/v2/install | bash
cd ~ && cp -r /mnt/c/Users/TU_USUARIO/Downloads/opencode-multiagent-kit .
cd opencode-multiagent-kit && bash install-linux.sh
```

Los proyectos en `/mnt/c/...` funcionan; para velocidad, cópialos a `~/code`. La config queda dentro de WSL (`~/.config/opencode`), no en Windows.

**Nativo (PowerShell 5.1+):**

```powershell
powershell -ExecutionPolicy Bypass -File .\install-windows.ps1
```

- Instala OpenCode con el binario de Windows o `npm install -g @opencode/cli`.
- Requiere `opencode`, `git` y `npm` en el PATH. No necesita Python ni Git Bash.
- La config vive en `C:\Users\TU_USUARIO\.config\opencode`.
- El script escribe la ruta del plugin con barras normales (`C:/Users/.../node_modules/superpowers`), que OpenCode acepta.
- Si `npm install` del plugin falla por git, verifica `git --version` en esa misma terminal.

## Instalación

| Sistema | Comando |
|---|---|
| Linux, macOS o WSL | `bash install-linux.sh` |
| Windows nativo | `powershell -ExecutionPolicy Bypass -File .\install-windows.ps1` |

`install.sh` sigue existiendo como alias de `install-linux.sh`.

Por defecto usa `v4-pro` donde el juicio importa y `flash` donde prima la velocidad. Para forzar todo a flash:

```bash
MODEL_PRIMARY=deepseek/deepseek-flash \
MODEL_SUB=deepseek/deepseek-flash \
MODEL_REVIEW=deepseek/deepseek-flash \
bash install-linux.sh
```

En PowerShell:

```powershell
$env:MODEL_PRIMARY = "deepseek/deepseek-v4-pro"
$env:MODEL_SUB = "deepseek/deepseek-flash"
$env:MODEL_REVIEW = "deepseek/deepseek-v4-pro"
.\install-windows.ps1
```

Opciones:

| Variable | Efecto |
|---|---|
| `MODEL_PRIMARY` | `orchestrator` y `plan` |
| `MODEL_SUB` | `build`, exploración, ejecución, verificación, docs e investigación |
| `MODEL_REVIEW` | `plan-runner`, `code-reviewer`, `security-reviewer` y `spec-critic` |
| `KEEP_DEFAULT_AGENT=1` | No pone `build` como agente por defecto |
| `OPENCODE_CONFIG_DIR` | Config destino (por defecto `~/.config/opencode`) |
| `ORCH_REF` / `SP_REF` | Fija otra versión/commit de los repos |

El script es idempotente y hace backup de `opencode.json` y de los agentes que sobrescribe. **No toca ningún proyecto**; todo va a la config global. Los dos instaladores hacen lo mismo; solo cambian las rutas y el formato de las variables de entorno.

### Qué escribe

```text
~/.config/opencode/
├── agents/                 # 11 agentes endurecidos (orchestrator, code-executor, ...)
├── skills/                 # 5 skills del orquestador
├── node_modules/superpowers/
├── AGENTS.md               # reglas globales + bloque gestionado del kit (no pisa tu contenido)
└── opencode.json           # plugins, default_agent y modelos por agente
```

El kit también trae `templates/` (AGENTS.md por stack, esqueletos de proyecto, plantilla de plan universal, pre-commit y CI) y `init-project.sh` para crear un proyecto o aplicarlos a uno existente.

`AGENTS.md` y los agentes son globales: aplican a todos los proyectos. Si dos proyectos necesitan equipos distintos, sobreescribe en `.opencode/` del proyecto (ver abajo).

## Endurecimiento aplicado

El kit no usa los agentes upstream tal cual; los endurece antes de instalarlos:

- **`plan-runner`**: solo puede escribir bajo `.opencode/plans/**` y ejecutar comandos de lectura (`ls`, `cat`, `rg`, `git diff`, `go list`). No muta el repo.
- **Revisores** (`code-reviewer`, `docs-reviewer`, `security-reviewer`, `host-security-investigator`): `git` en modo lectura (`diff`, `log`, `show`, `status`); sin `commit` ni `push`.
- **`code-executor`**: `sudo` denegado; `rm`, `curl`/`wget`, `ssh`/`scp` y git destructivo pasan por confirmación; `git push` denegado. No puede tocar `.env*`, claves, `.ssh` ni `.git`.
- **`orchestrator`**: sin lectura ni escritura del repo; solo planes. No puede usar `writing-plans` directamente: debe delegar en `plan-runner` y exigir un archivo en `.opencode/plans/`. Revisa seguridad del plan antes de aprobar y lanza los revisores en paralelo cuando el diff está estable.
- **Secretos**: lectura de `.env*`, `*.pem`, `*.key`, `id_rsa*` y `.ssh` denegada en exploración, planificación, ejecución, revisión y verificación (`.env.example`, `.sample` y `.template` siguen permitidos).
- **Skills**: allowlist explícita; se quitaron `pythonic-quality` y `security-investigation` (no aportan a un proyecto de app).
- **Modelos híbridos**: pro para planificar/revisar, flash para explorar/ejecutar/verificar.

## Calidad y gates

Proyecto nuevo:

```bash
bash init-project.sh --new ~/proyectos/mi-app --stack go
```

Crea directorio, `git init`, esqueleto mínimo que compila y responde (`GET /` → 200), `README.md`, `.gitignore`, `.env.example`, y luego los gates. `--stack` es obligatorio aquí porque no hay marcador que detectar.

Proyecto existente:

```bash
bash init-project.sh ~/proyectos/mi-app
```

Detecta el stack por `go.mod`, `package.json`, `pyproject.toml`/`requirements*.txt`/`setup.py`, `Cargo.toml` o `pom.xml`/`build.gradle(.kts)`. Si no lo reconoce, instala el perfil `generic` y no inventa un CI.

| Stack | Hook rápido | CI |
|---|---|---|
| Go | `gofmt` staged + `go vet` | vet, build, `test -race`, cobertura mín. 50%, `govulncheck`, `gosec`, lint |
| Node/TS | Prettier staged | `tsc`, lint, test, build, audit |
| Python | `ruff` staged | ruff, mypy (si está configurado), pytest, `pip-audit` |
| Rust | `cargo fmt --check` | fmt, clippy `-D warnings`, test, `cargo audit` |
| Java | `google-java-format` staged si está instalado | wrapper Maven/Gradle o `mvn verify` |
| Generic | whitespace + `gitleaks` | no; define tu workflow |

Todos instalan `.opencode/smoke.sh`: comprueba que el proyecto compila, arranca y responde 200. Es la evidencia de "funciona", separada de los tests.

Opciones: `--new <ruta>`, `--stack go|node|python|rust|java|generic`, `--force`, `--list`. No hace preguntas. En repos polyglot, elige con `--stack` (por defecto gana el primer marcador detectado).

El hook está pensado para ser rápido (<5 s en proyectos pequeños/medianos); la suite completa, `-race` y las auditorías van al CI. En repos Go grandes, cambia `go test ./...` del hook por `go test -short ./...`. `init-project.sh` es bash: Linux/macOS/WSL o Git Bash en Windows. El hook necesita la toolchain del stack en el PATH.

## Verificación

1. Reinicia OpenCode (los plugins y agentes se cargan al arrancar).
2. Comprueba:

```bash
opencode debug agents   # orchestrator, code-executor, security-reviewer...
opencode plugin list    # superpowers (y los plugins que ya tuvieras)
```

En OpenCode V1 el comando es `opencode agent list` y la clave de config es `plugin`.

3. En cualquier repo:

```bash
opencode --agent orchestrator
```

Petición de prueba: `Planifica añadir un endpoint /health con test.` Debe crear un plan en `.opencode/plans/` y pedir aprobación antes de escribir código.

## Cómo usarlo

### Elegir agente

| Situación | Agente | Cómo |
|---|---|---|
| Feature, refactor o bug no trivial | `orchestrator` | `opencode --agent orchestrator` |
| Cambio de una línea o pregunta rápida | `build` | por defecto, u `opencode --agent build` |
| Solo quiero un plan, sin ejecutar | `plan` | `opencode --agent plan` |

No hace falta llamar a los subagentes a mano: el orquestador los convoca según la tarea.

### Ciclo completo

1. Escribes la petición en la sesión de `orchestrator`.
2. `plan-runner` guarda un plan en `.opencode/plans/` del proyecto.
3. Si el cambio toca auth, red, ficheros o entrada externa, `security-reviewer` revisa el plan antes de aprobar.
4. La TUI muestra una pregunta `PlanApprove` con `Approve` / `Revise`.
5. Si eliges `Approve`, respondes `Ejecuta el plan aprobado`.
6. `code-executor` implementa por partes; después pasan `test-verifier` y, en paralelo cuando el diff está estable, `code-reviewer`, `security-reviewer` y `docs-reviewer`.
7. Tú revisas el diff. Ningún agente hace commit ni push por su cuenta.

Si el plan no te convence, elige `Revise` y explica qué cambiar. Se reescribe antes de tocar código.

### Ejemplos de peticiones

**Feature nueva** (funciona mejor con stack y criterios explícitos):

> Quiero una app de gatos: backend y frontend en Go, un solo binario, frontend embebido con `embed.FS`. Galería editorial responsive con imágenes de cataas, caché en memoria, `GET /api/cats?n=9` y `GET /img/{id}`, skeletons, lightbox y botón "más gatos". Sin frameworks JS. Incluye tests y README. Planifica primero; no escribas código hasta que apruebe.

**Bug**:

> Hay un bug: al enviar el formulario vacío la API devuelve 500 en vez de 400. Reproduce el fallo, encuentra la causa raíz y aplica el fix mínimo con un test que lo cubra. No refactorices nada más.

**Revisión de seguridad** (solo informe):

> Revisa la seguridad del módulo de autenticación: sesiones, cookies, validación de entrada y secretos. No cambies código; devuelve hallazgos con severidad y evidencia.

**Documentación**:

> Actualiza el README con las variables de entorno nuevas y un ejemplo de arranque. No toques el código.

### Tareas pequeñas

El orquestador es deliberadamente lento: planifica y delega. Para un typo, un rename o una pregunta, usa `build`; es más rápido y barato. La regla práctica: si lo harías en menos de cinco minutos, no abras el orquestador.

### Qué NO hace

- No hace `git commit` ni `git push` por su cuenta. `code-executor` pide confirmación para commit y tiene push denegado; los revisores solo pueden leer git.
- No instala el plugin de handoff automático del upstream (`plan-post-approval`): usa la API V1 y falla en OpenCode V2. Por eso el paso 5 es manual.
- No comparte tu código con servicios distintos del proveedor del modelo que configures.

Los planes quedan en `.opencode/plans/` del proyecto. Decide si los commiteas (documentación) o los ignoras:

```gitignore
.opencode/plans/
```

### Cambiar modelos

El defecto es híbrido: pro para planificar y revisar, flash para explorar, ejecutar y verificar. Para forzar todo a flash:

```bash
MODEL_PRIMARY=deepseek/deepseek-flash \
MODEL_SUB=deepseek/deepseek-flash \
MODEL_REVIEW=deepseek/deepseek-flash \
bash install-linux.sh
```

O por proyecto, sin tocar la config global (`.opencode/opencode.json`):

```json
{
  "agent": {
    "orchestrator": { "model": "deepseek/deepseek-v4-pro" },
    "code-executor": { "model": "deepseek/deepseek-flash" }
  }
}
```

## Configuración por proyecto

La config global es el punto de partida. Para un proyecto concreto, crea `.opencode/agents/<id>.md`, `.opencode/skills/<nombre>/SKILL.md` o `.opencode/opencode.json`: lo del proyecto tiene prioridad. Para crear un proyecto con esqueleto, convenciones, plan, hook y CI de una vez, usa `bash init-project.sh --new <ruta> --stack <stack>`; para un repo existente, `bash init-project.sh <ruta>` (ver **Calidad y gates**).

## Instalación manual

Si no quieres ejecutar el script:

```bash
git clone https://github.com/fxcl/opencode-orchestrator /tmp/orchestrator
git clone --branch v7.0.2 https://github.com/obra/superpowers /tmp/superpowers

mkdir -p ~/.config/opencode/{agents,skills}
cp /tmp/orchestrator/agents/*.md ~/.config/opencode/agents/
cp /ruta/al/kit/agents/*.md ~/.config/opencode/agents/   # versiones endurecidas
cp -R /tmp/orchestrator/skills/. ~/.config/opencode/skills/
cp /tmp/orchestrator/AGENTS.md ~/.config/opencode/AGENTS.md   # solo si no tienes uno
# y fusiona templates/global-AGENTS.md dentro de AGENTS.md (bloque entre marcadores)

npm install --prefix ~/.config/opencode \
  "superpowers@git+https://github.com/obra/superpowers.git#v7.0.2"
```

Sustituye en los agentes `opencode-go/deepseek-v4-flash` y `opencode-go/deepseek-v4-pro` por tus modelos. Los instaladores lo hacen solos, incluido el mapeo de reviews a `MODEL_REVIEW`.

En `~/.config/opencode/opencode.json`:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "model": "deepseek/deepseek-flash",
  "plugins": [
    "@dietrichgebert/ponytail",
    "/home/TU_USUARIO/.config/opencode/node_modules/superpowers"
  ],
  "default_agent": "build",
  "agent": {
    "orchestrator": { "model": "deepseek/deepseek-v4-pro", "reasoningEffort": "max" },
    "plan": { "model": "deepseek/deepseek-v4-pro", "reasoningEffort": "max" },
    "plan-runner": { "model": "deepseek/deepseek-v4-pro", "reasoningEffort": "max" },
    "code-reviewer": { "model": "deepseek/deepseek-v4-pro", "reasoningEffort": "max" },
    "security-reviewer": { "model": "deepseek/deepseek-v4-pro", "reasoningEffort": "max" },
    "spec-critic": { "model": "deepseek/deepseek-v4-pro", "reasoningEffort": "max" },
    "build": { "model": "deepseek/deepseek-flash" },
    "code-executor": { "model": "deepseek/deepseek-flash" },
    "code-explorer": { "model": "deepseek/deepseek-flash" },
    "test-verifier": { "model": "deepseek/deepseek-flash" },
    "docs-reviewer": { "model": "deepseek/deepseek-flash" },
    "api-docs-researcher": { "model": "deepseek/deepseek-flash" },
    "host-security-investigator": { "model": "deepseek/deepseek-flash" }
  }
}
```

No uses `~` en la ruta del plugin: OpenCode la interpreta como nombre de paquete. Usa la ruta absoluta.

## Problemas frecuentes

| Síntoma | Causa / solución |
|---|---|
| `debug agents` no muestra nada | Config en otra ruta o falta reiniciar. Comprueba `opencode debug config`. |
| `model not found` | El ID no existe en tu proveedor. Ejecuta `opencode models` y usa el ID exacto. |
| Superpowers no aparece | La ruta del plugin debe ser absoluta y existir `node_modules/superpowers/index.js`. |
| `Plugin failed: .../plan-post-approval.ts` | Es un plugin de la API V1. El kit no lo instala; si lo copiaste a mano, bórralo. El flujo funciona pidiendo a `orchestrator` que ejecute el plan aprobado. |
| `question` cancelada en `opencode run` | Es una ejecución no interactiva y no puede pedir aprobación. Usa la TUI para el gate `PlanApprove`. |
| `--new` pide `--stack` | No hay marcador que detectar en un directorio vacío. Indica `--stack go|node|python|rust|java|generic`. |
| `--new` dice "ya existe y no está vacío" | Usa `bash init-project.sh <ruta>` para añadir gates a ese repo, o elige otra ruta. |
| `smoke` falla al arrancar | Comprueba que la toolchain del stack está en el PATH y que el puerto 18080 está libre. |
| `opencode.json` con comentarios | El script espera JSON estricto. Fusiona el ejemplo a mano. |
| El pre-commit dice que falta la toolchain | Añade el binario de tu stack (Go, Node, Python, Rust o Java) al PATH de la terminal donde commiteas. |
| `gitleaks` bloquea el commit | Puede haber un secreto real o una versión sin `--staged`. Actualiza gitleaks; no lo desactives sin revisar. |
| Windows | En WSL usa `bash install-linux.sh`; en nativo, `install-windows.ps1`. La config está en `C:\Users\TU_USUARIO\.config\opencode`. |

## Desinstalar

```bash
# 1. Restaura el backup
ls ~/.config/opencode/opencode.json.bak.*
cp ~/.config/opencode/opencode.json.bak.FECHA ~/.config/opencode/opencode.json

# 2. Borra lo instalado
rm -rf ~/.config/opencode/agents/{orchestrator,plan-runner,code-executor,code-explorer,code-reviewer,docs-reviewer,test-verifier,security-reviewer,host-security-investigator,spec-critic,api-docs-researcher}.md
rm -rf ~/.config/opencode/skills/{agent-delegation,task-management,pythonic-quality,security-investigation,skill-creator}
rm -rf ~/.config/opencode/node_modules/superpowers
```

`AGENTS.md` solo bórralo si lo instaló este kit. Si ya existía, elimina solo el bloque entre `<!-- opencode-multiagent-kit:start -->` y `<!-- opencode-multiagent-kit:end -->`.

## Límites y seguridad

- Esto son **prompts y permisos de OpenCode**, más los gates de proyecto (`init-project.sh`). El aislamiento real depende de los permisos de cada agente y de que el hook/CI estén activos.
- El plugin de handoff automático del upstream (`plan-post-approval`) **no se instala**: usa la API V1 y falla en OpenCode V2. Tras aprobar el plan, pide la ejecución a `orchestrator`.
- No uses `--auto` con agentes que tengan ejecución y escritura. `code-executor` puede escribir; `orchestrator` no.
- Revisa los prompts antes de confiar en ellos y fija commits/tags (el script ya lo hace).
- Los agentes leen y ejecutan comandos en tu repo: no les des credenciales que no quieras exponer.
- Los gates de CI usan `@latest` en algunas herramientas para no fijar versiones obsoletas; en un repo real, pinea versiones.
- Los gates de proyecto se instalan por repo con `init-project.sh`; no son globales. Ejecútalo en cada proyecto que quieras proteger.
- Los permisos por patrón **no son un sandbox**: bloquean comandos conocidos, no aislamiento de kernel. Para código no confiable, ejecuta OpenCode en un contenedor o usuario sin privilegios.
- Licencias: `opencode-orchestrator` es MIT (© 2026 tempont); Superpowers es MIT (© obra). Este kit solo los configura y endurece.

## Versiones fijadas

| Componente | Ref |
|---|---|
| `fxcl/opencode-orchestrator` | `7ca5ca7` |
| `obra/superpowers` | `v7.0.2` |

Los agentes endurecidos viven en `agents/` y se generan desde esa ref con `python3 tools/harden_agents.py <upstream> agents`. El instalador copia primero el upstream y luego esta capa.

Para actualizar: `ORCH_REF=main SP_REF=main bash install-linux.sh` y revisa el diff de los agentes.
