#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
source "$ROOT/scripts/check-toolchain.sh"

cd "$ROOT"
swift build -c release
"$ROOT/scripts/assemble-app.sh" "$ROOT/.build/release/ESStatus"
