#!/bin/zsh
set -u

ROOT="${0:A:h}"
clear
echo "RStudio Status 설치"
echo "===================="
echo

if ! xcode-select -p >/dev/null 2>&1; then
    echo "Xcode Command Line Tools 설치 창을 엽니다."
    echo "설치가 끝난 뒤 이 파일을 다시 실행해 주세요."
    xcode-select --install 2>/dev/null || true
    echo
    read "?Enter 키를 누르면 종료합니다. "
    exit 1
fi

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
