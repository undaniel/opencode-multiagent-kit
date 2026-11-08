#!/usr/bin/env bash
# Instala el kit multiagente (orchestrator + superpowers) en Linux, macOS o WSL.
# Uso: bash install-linux.sh
# Variables: MODEL_PRIMARY, MODEL_SUB, MODEL_REVIEW, KEEP_DEFAULT_AGENT=1, OPENCODE_CONFIG_DIR
set -euo pipefail

KIT_DIR="$(cd "$(dirname "$0")" && pwd)"
ORCH_REPO="https://github.com/fxcl/opencode-orchestrator.git"
ORCH_REF="${ORCH_REF:-7ca5ca771367e583692887452bf161bde4fc5ee9}"
SP_REPO="https://github.com/obra/superpowers.git"
SP_REF="${SP_REF:-v7.0.2}"
MODEL_PRIMARY="${MODEL_PRIMARY:-deepseek/deepseek-v4-pro}"
MODEL_SUB="${MODEL_SUB:-deepseek/deepseek-flash}"
MODEL_REVIEW="${MODEL_REVIEW:-$MODEL_PRIMARY}"
TARGET="${OPENCODE_CONFIG_DIR:-$HOME/.config/opencode}"
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/opencode-multiagent"
STAMP="$(date +%Y%m%d%H%M%S)"
PYTHON="${PYTHON:-python3}"

for bin in opencode git "$PYTHON" npm; do
  command -v "$bin" >/dev/null || { echo "Falta '$bin' en PATH."; exit 1; }
done

[ -d "$KIT_DIR/agents" ] || { echo "Falta la carpeta agents/ junto al instalador."; exit 1; }
[ -f "$KIT_DIR/templates/global-AGENTS.md" ] || { echo "Falta templates/global-AGENTS.md."; exit 1; }

mkdir -p "$CACHE" "$TARGET/agents" "$TARGET/skills"

clone_ref() {
  local repo="$1" ref="$2" dir="$3"
  if [ -d "$dir/.git" ]; then
    git -C "$dir" fetch -q --tags origin
    git -C "$dir" checkout -q "$ref"
  else
    git clone -q "$repo" "$dir"
    git -C "$dir" checkout -q "$ref"
  fi
}

echo "==> Descargando versiones fijas"
clone_ref "$ORCH_REPO" "$ORCH_REF" "$CACHE/orchestrator"
clone_ref "$SP_REPO" "$SP_REF" "$CACHE/superpowers"

echo "==> Copiando agentes y skills"
for f in "$CACHE"/orchestrator/agents/*.md; do
  dest="$TARGET/agents/$(basename "$f")"
  [ -e "$dest" ] && cp "$dest" "$dest.bak.$STAMP"
  cp "$f" "$dest"
done
cp -R "$CACHE"/orchestrator/skills/. "$TARGET/skills/"
echo "==> Aplicando agentes endurecidos del kit"
for f in "$KIT_DIR"/agents/*.md; do
  cp "$f" "$TARGET/agents/$(basename "$f")"
done
# El plugin plan-post-approval del upstream es API V1 y falla en OpenCode V2.
# Con el orquestador no hace falta: el handoff tras aprobar se pide a mano.
echo "    plugin V1 omitido (plan-post-approval)"
AGENTS_DEST="$TARGET/AGENTS.md"
if [ ! -f "$AGENTS_DEST" ]; then
  cp "$CACHE/orchestrator/AGENTS.md" "$AGENTS_DEST"
fi
"$PYTHON" - "$AGENTS_DEST" "$KIT_DIR/templates/global-AGENTS.md" <<'PY'
import re, sys

path, block_path = sys.argv[1], sys.argv[2]
text = open(path).read()
text = text.replace(
    "- User communication in English.",
    "- User communication in the user's language.",
)
block = open(block_path).read().strip()
pattern = re.compile(
    r"<!-- opencode-multiagent-kit:start -->.*?<!-- opencode-multiagent-kit:end -->",
    re.S,
)
if pattern.search(text):
    text = pattern.sub(block, text)
else:
    text = text.rstrip() + "\n\n" + block + "\n"
open(path, "w").write(text)
PY
echo "    reglas del kit fusionadas en AGENTS.md"

echo "==> Ajustando modelos a $MODEL_PRIMARY / $MODEL_SUB (reviews: $MODEL_REVIEW)"
"$PYTHON" - "$TARGET/agents" "$MODEL_PRIMARY" "$MODEL_SUB" "$MODEL_REVIEW" <<'PY'
import pathlib, sys
root, primary, sub, review = pathlib.Path(sys.argv[1]), sys.argv[2], sys.argv[3], sys.argv[4]
review_agents = {"plan-runner.md", "code-reviewer.md", "security-reviewer.md", "spec-critic.md"}
for path in root.glob("*.md"):
    text = path.read_text()
    model = review if path.name in review_agents else sub
    new = text.replace("opencode-go/deepseek-v4-pro", primary).replace(
        "opencode-go/deepseek-v4-flash", model
    )
    if new != text:
        path.write_text(new)
PY

echo "==> Instalando superpowers"
if [ ! -d "$TARGET/node_modules/superpowers" ]; then
  npm install --prefix "$TARGET" --no-audit --no-fund \
    "superpowers@git+${SP_REPO}#${SP_REF}"
else
  echo "    ya estaba instalado"
fi

echo "==> Fusionando opencode.json (backup previo)"
[ -f "$TARGET/opencode.json" ] && cp "$TARGET/opencode.json" "$TARGET/opencode.json.bak.$STAMP"
SP_PATH="$TARGET/node_modules/superpowers"
"$PYTHON" - "$TARGET/opencode.json" "$SP_PATH" \
  "$MODEL_PRIMARY" "$MODEL_SUB" "$MODEL_REVIEW" "${KEEP_DEFAULT_AGENT:-0}" <<'PY'
import json, os, sys

path, sp_path, primary, sub, review, keep_default = sys.argv[1:7]
cfg = {}
if os.path.exists(path) and os.path.getsize(path):
    try:
        with open(path) as fh:
            cfg = json.load(fh)
    except json.JSONDecodeError as err:
        sys.exit(f"opencode.json no es JSON válido ({err}). Fusiona a mano el ejemplo del README.")

plugins = cfg.get("plugins")
if plugins is None:
    plugins = cfg.pop("plugin", []) or []
plugins = [p for p in plugins if "superpowers" not in str(p)]
if sp_path not in plugins:
    plugins.append(sp_path)
cfg["plugins"] = plugins

cfg.setdefault("model", sub)
if keep_default != "1":
    cfg["default_agent"] = "build"

agents = cfg.setdefault("agent", {})

def set_model(name, model, effort=None):
    block = agents.setdefault(name, {})
    block["model"] = model
    if effort:
        block["reasoningEffort"] = effort
    else:
        block.pop("reasoningEffort", None)

# Rápido por defecto; pro solo donde el juicio importa.
set_model("orchestrator", primary, "max")
agents["orchestrator"]["plan_post_approval_handoff_agent"] = "orchestrator"
set_model("plan", primary, "max")
set_model("plan-runner", review, "max")
set_model("code-reviewer", review, "max")
set_model("security-reviewer", review, "max")
set_model("spec-critic", review, "max")
set_model("build", sub)
for name in (
    "code-explorer", "code-executor", "test-verifier", "docs-reviewer",
    "api-docs-researcher", "host-security-investigator",
):
    set_model(name, sub)

with open(path, "w") as fh:
    json.dump(cfg, fh, indent=2, ensure_ascii=False)
    fh.write("\n")
PY

"$PYTHON" -m json.tool "$TARGET/opencode.json" >/dev/null

echo
echo "==> Listo. Config: $TARGET/opencode.json"
echo "    Reinicia OpenCode y verifica:"
echo "      opencode debug agents   # deben aparecer orchestrator y code-executor"
echo "      opencode plugin list    # debe aparecer superpowers"
echo
echo "    Por defecto:  opencode                    # agente build (rápido)"
echo "    Con equipo:   opencode --agent orchestrator"
