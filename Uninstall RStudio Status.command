#!/bin/zsh
set -u

ROOT="${0:A:h}"
clear
echo "RStudio Status 제거"
echo "===================="
echo

chmod +x "$ROOT/uninstall.sh"
"$ROOT/uninstall.sh"

echo
read "?Enter 키를 누르면 창을 닫습니다. "
