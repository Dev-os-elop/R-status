#!/bin/zsh
set -u

ROOT="${0:A:h}"
clear
echo "ES Status 설치"
echo "=============="
echo

chmod +x "$ROOT/install.sh" "$ROOT/uninstall.sh" "$ROOT/Resources/"*.sh "$ROOT/scripts/"*.sh

if "$ROOT/install.sh"; then
    echo
    echo "설치가 완료되었습니다. RStudio를 재시작해 주세요."
else
    echo
    echo "설치에 실패했습니다. 위 오류 메시지를 확인해 주세요."
fi

echo
read "?Enter 키를 누르면 창을 닫습니다. "
