#!/usr/bin/env bash
# Crea un proyecto nuevo o añade gates a uno existente, según su stack.
# Uso:
#   bash init-project.sh [ruta] [--stack go|node|python|rust|java|generic] [--force] [--list]
#   bash init-project.sh --new <ruta> --stack <stack>
set -euo pipefail

PROJECT="."
FORCE=0
STACK=""
NEW=0
KIT="$(cd "$(dirname "$0")" && pwd)"
STACKS="$KIT/templates/stacks"
SKELETONS="$KIT/templates/skeletons"

while [ $# -gt 0 ]; do
  case "$1" in
    --new)
      [ $# -ge 2 ] || { echo "Falta la ruta de --new"; exit 1; }
      NEW=1
      PROJECT="$2"
      shift
      ;;
    --force) FORCE=1 ;;
    --stack)
      [ $# -ge 2 ] || { echo "Falta el valor de --stack"; exit 1; }
      STACK="$2"
      shift
      ;;
    --stack=*) STACK="${1#--stack=}" ;;
    --list)
      echo "Stacks disponibles:"
      for d in "$STACKS"/*/; do echo "  - $(basename "$d")"; done
      exit 0
      ;;
    -*) echo "Opción desconocida: $1"; exit 1 ;;
    *) PROJECT="$1" ;;
  esac
  shift
done

if [ "$NEW" -eq 1 ]; then
  [ -n "$STACK" ] || { echo "--new requiere --stack (usa --list)"; exit 1; }
  if [ -e "$PROJECT" ] && [ -n "$(ls -A "$PROJECT" 2>/dev/null)" ]; then
    echo "Ya existe y no está vacío: $PROJECT"
    echo "Para añadir gates a un repo existente: bash init-project.sh $PROJECT"
    exit 1
  fi
  mkdir -p "$PROJECT"
fi

git -C "$PROJECT" rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
  if [ "$NEW" -eq 1 ]; then
    git -C "$PROJECT" init -q
  else
    echo "No es un repositorio git: $PROJECT"
    exit 1
  fi
}
PROJECT_ABS="$(cd "$PROJECT" && pwd)"

if [ -z "$STACK" ]; then
  if [ -f "$PROJECT/go.mod" ]; then
    STACK=go
  elif [ -f "$PROJECT/package.json" ]; then
    STACK=node
  elif [ -f "$PROJECT/pyproject.toml" ] || [ -f "$PROJECT/requirements.txt" ] || [ -f "$PROJECT/requirements-dev.txt" ] || [ -f "$PROJECT/setup.py" ] || [ -f "$PROJECT/setup.cfg" ]; then
    STACK=python
  elif [ -f "$PROJECT/Cargo.toml" ]; then
    STACK=rust
  elif [ -f "$PROJECT/pom.xml" ] || [ -f "$PROJECT/build.gradle" ] || [ -f "$PROJECT/build.gradle.kts" ]; then
    STACK=java
  else
    STACK=generic
  fi
fi

STACK_DIR="$STACKS/$STACK"
[ -d "$STACK_DIR" ] || { echo "Stack desconocido: $STACK (usa --list)"; exit 1; }

echo "Stack: $STACK"

NAME="$(basename "$PROJECT_ABS")"
NAME_SAFE="$(printf '%s' "$NAME" | tr '[:upper:] ' '[:lower:]-' | tr -cd 'a-z0-9._-')"

sed_inplace() {
  if sed --version >/dev/null 2>&1; then
    sed -i "$@"
  else
    sed -i '' "$@"
  fi
}

if [ "$NEW" -eq 1 ] && [ -d "$SKELETONS/common" ]; then
  cp -R "$SKELETONS/common"/. "$PROJECT"/
fi
if [ "$NEW" -eq 1 ] && [ -d "$SKELETONS/$STACK" ]; then
  cp -R "$SKELETONS/$STACK"/. "$PROJECT"/
  echo "  esqueleto: $STACK"
fi

case "$STACK" in
  go)
    if [ "$NEW" -eq 1 ]; then
      if command -v go >/dev/null 2>&1; then
        (cd "$PROJECT" && go mod init "$NAME_SAFE" >/dev/null)
      else
        printf 'module %s\n\ngo 1.21\n' "$NAME_SAFE" > "$PROJECT/go.mod"
        echo "  aviso: go no está en PATH; go.mod creado a mano"
      fi
      # `go build ./...` deja un binario con el nombre del módulo en la raíz.
      printf '/%s\n' "$NAME_SAFE" >> "$PROJECT/.gitignore"
    fi
    ;;
  node|rust|java)
    if [ "$NEW" -eq 1 ]; then
      for f in package.json Cargo.toml pom.xml; do
        [ -f "$PROJECT/$f" ] && sed_inplace "s/__NAME__/$NAME_SAFE/g" "$PROJECT/$f"
      done
    fi
    ;;
esac

if [ "$NEW" -eq 1 ] && [ ! -f "$PROJECT/README.md" ]; then
  case "$STACK" in
    go) RUN="go run ."; TESTS="go test ./..." ;;
    node) RUN="npm start"; TESTS="npm test" ;;
    python) RUN="python3 app.py"; TESTS="pytest" ;;
    rust) RUN="cargo run"; TESTS="cargo test" ;;
    java) RUN="javac -d out \$(find src -name '*.java') && java -cp out Main"; TESTS="mvn verify (o ./mvnw verify)" ;;
    *) RUN="(define el comando de arranque)"; TESTS="(define el comando de tests)" ;;
  esac
  cat > "$PROJECT/README.md" <<EOF
# $NAME

Proyecto $STACK creado con opencode-multiagent-kit.

## Arrancar

\`\`\`bash
$RUN
\`\`\`

## Tests

\`\`\`bash
$TESTS
\`\`\`

## Comprobar que arranca

\`\`\`bash
bash .opencode/smoke.sh
\`\`\`

## Agentes

- \`opencode\` — cambios pequeños.
- \`opencode --agent orchestrator\` — features, refactors y cambios ambiguos.
EOF
fi

copy_file() {
  local src="$1" dest="$2"
  if [ -e "$dest" ] && [ "$FORCE" -ne 1 ]; then
    echo "  existe, no toco: ${dest#"$PROJECT_ABS"/}"
    return
  fi
  mkdir -p "$(dirname "$dest")"
  cp "$src" "$dest"
  echo "  ok: ${dest#"$PROJECT_ABS"/}"
}

mkdir -p "$PROJECT/.opencode/plans"
printf '%s\n' "$STACK" > "$PROJECT/.opencode/stack"

copy_file "$STACK_DIR/AGENTS.md" "$PROJECT/AGENTS.md"
copy_file "$KIT/templates/plans/TEMPLATE.md" "$PROJECT/.opencode/plans/TEMPLATE.md"
copy_file "$KIT/tools/smoke.sh" "$PROJECT/.opencode/smoke.sh"
chmod +x "$PROJECT/.opencode/smoke.sh"

if [ -f "$STACK_DIR/pre-commit" ]; then
  copy_file "$STACK_DIR/pre-commit" "$PROJECT/.githooks/pre-commit"
  chmod +x "$PROJECT/.githooks/pre-commit"
  current=$(git -C "$PROJECT" config --get core.hooksPath || true)
  if [ -n "$current" ] && [ "$current" != ".githooks" ]; then
    echo "  aviso: core.hooksPath era '$current'; lo cambio a .githooks"
  fi
  git -C "$PROJECT" config core.hooksPath .githooks
else
  echo "  sin pre-commit para $STACK"
fi

if [ -f "$STACK_DIR/ci.yml" ]; then
  copy_file "$STACK_DIR/ci.yml" "$PROJECT/.github/workflows/ci.yml"
else
  echo "  sin CI predefinido para $STACK: añade build/test/lint a AGENTS.md y tu propio workflow"
fi

echo
echo "Listo: $PROJECT_ABS"
echo "  bash .opencode/smoke.sh          # comprueba que arranca"
echo "  opencode                         # cambios pequeños (build)"
echo "  opencode --agent orchestrator    # features y refactors"
