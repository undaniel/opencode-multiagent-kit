#!/usr/bin/env bash
# Comprueba que el proyecto compila/arranca y responde. Uso: bash .opencode/smoke.sh [--port N]
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

PORT="${PORT:-18080}"
while [ $# -gt 0 ]; do
  case "$1" in
    --port)
      [ $# -ge 2 ] || { echo "Falta el valor de --port"; exit 1; }
      PORT="$2"
      shift
      ;;
    *) echo "Opción desconocida: $1"; exit 1 ;;
  esac
  shift
done

STACK="$(cat .opencode/stack 2>/dev/null || true)"
[ -n "$STACK" ] || { echo "smoke: falta .opencode/stack (ejecuta init-project.sh)"; exit 1; }

tmp="$(mktemp -d)"
pid=""
cleanup() {
  [ -n "$pid" ] && kill "$pid" 2>/dev/null || true
  rm -rf "$tmp"
}
trap cleanup EXIT

wait_http() {
  for _ in $(seq 1 40); do
    code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 1 "http://127.0.0.1:$PORT/" || true)"
    [ "$code" = "200" ] && return 0
    sleep 0.25
  done
  return 1
}

tcp_error() {
  echo "smoke: no responde en http://127.0.0.1:$PORT/ ($1)"
  exit 1
}

case "$STACK" in
  go)
    command -v go >/dev/null 2>&1 || { echo "smoke: go no está en PATH"; exit 1; }
    go build -o "$tmp/app" .
    PORT="$PORT" "$tmp/app" & pid=$!
    wait_http || tcp_error "go"
    ;;
  node)
    command -v node >/dev/null 2>&1 || { echo "smoke: node no está en PATH"; exit 1; }
    PORT="$PORT" node src/server.js & pid=$!
    wait_http || tcp_error "node"
    ;;
  python)
    command -v python3 >/dev/null 2>&1 || { echo "smoke: python3 no está en PATH"; exit 1; }
    PORT="$PORT" python3 app.py & pid=$!
    wait_http || tcp_error "python"
    ;;
  java)
    command -v javac >/dev/null 2>&1 || { echo "smoke: javac no está en PATH"; exit 1; }
    javac -d "$tmp/out" $(find src -name '*.java')
    PORT="$PORT" java -cp "$tmp/out" Main & pid=$!
    wait_http || tcp_error "java"
    ;;
  rust)
    command -v cargo >/dev/null 2>&1 || { echo "smoke: cargo no está en PATH"; exit 1; }
    cargo build --quiet
    cargo test --quiet
    out="$(cargo run --quiet)"
    case "$out" in
      *hola*) ;;
      *) echo "smoke: salida inesperada de cargo run: $out"; exit 1 ;;
    esac
    ;;
  generic)
    echo "smoke: stack generic; define aquí tu comprobación de arranque"
    exit 0
    ;;
  *)
    echo "smoke: stack desconocido '$STACK'"
    exit 1
    ;;
esac

echo "smoke: OK ($STACK, :$PORT)"
