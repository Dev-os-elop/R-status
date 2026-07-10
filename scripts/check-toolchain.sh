#!/bin/zsh

# This file is sourced by install.sh so that a working full-Xcode toolchain can
# be selected for the rest of the installation through DEVELOPER_DIR.

rstudio_status_toolchain_works() {
    /usr/bin/xcrun --sdk macosx --show-sdk-path >/dev/null 2>&1 &&
        /usr/bin/xcrun --find swift >/dev/null 2>&1 &&
        /usr/bin/xcrun swift --version >/dev/null 2>&1 &&
        (cd "${ROOT:-${0:A:h:h}}" && /usr/bin/xcrun swift package describe --type json >/dev/null 2>&1)
}

if rstudio_status_toolchain_works; then
    return 0 2>/dev/null || exit 0
fi

# A broken or outdated standalone Command Line Tools installation may be
# selected even though a complete Xcode installation is available. Prefer a
# working Xcode for this installer without changing the user's global setting.
for xcode_app in /Applications/Xcode*.app(N); do
    developer_dir="$xcode_app/Contents/Developer"
    if [[ -d "$developer_dir" ]] && DEVELOPER_DIR="$developer_dir" rstudio_status_toolchain_works; then
        export DEVELOPER_DIR="$developer_dir"
        echo "사용 가능한 Xcode 도구를 찾았습니다: $xcode_app"
        return 0 2>/dev/null || exit 0
    fi
done

cat >&2 <<'EOF'
오류: macOS 개발 도구가 없거나 손상되어 앱을 빌드할 수 없습니다.

사진과 같은 'unable to lookup item PlatformPath' 오류는 대개 macOS 업데이트 후
Command Line Tools가 현재 macOS와 맞지 않거나 SDK 설치가 불완전할 때 발생합니다.

먼저 시스템 설정 → 일반 → 소프트웨어 업데이트에서 업데이트를 모두 설치하세요.
계속 실패하면 터미널에서 아래 명령을 차례로 실행해 개발 도구를 다시 설치하세요.

  sudo rm -rf /Library/Developer/CommandLineTools
  xcode-select --install

설치 창에서 완료한 후 'Install RStudio Status.command'를 다시 실행하세요.

전체 Xcode를 이미 설치했다면 다음 명령으로 선택한 뒤 다시 시도할 수도 있습니다.

  sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
EOF

return 1 2>/dev/null || exit 1
