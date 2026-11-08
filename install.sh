#!/usr/bin/env bash
# Compatibilidad: install.sh -> install-linux.sh (Linux, macOS, WSL).
set -euo pipefail
exec bash "$(dirname "$0")/install-linux.sh" "$@"
