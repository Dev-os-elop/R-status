#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
APP="$ROOT/dist/ES Status.app"
LEGACY_APP="$ROOT/dist/RStudio Status.app"
BINARY="${1:-}"
APP_ICON="$ROOT/Resources/ESStatus.icns"

if [[ -z "$BINARY" || ! -f "$BINARY" ]]; then
    echo "오류: 앱 실행 파일을 찾을 수 없습니다: $BINARY" >&2
    exit 1
fi

if [[ ! -f "$APP_ICON" ]]; then
    echo "오류: 앱 아이콘을 찾을 수 없습니다: $APP_ICON" >&2
    exit 1
fi

rm -rf "$APP" "$LEGACY_APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BINARY" "$APP/Contents/MacOS/ESStatus"
chmod +x "$APP/Contents/MacOS/ESStatus"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
cp "$APP_ICON" "$APP/Contents/Resources/CatOriginal.icns"
cp "$ROOT/Resources/install-addin.sh" "$APP/Contents/Resources/install-addin.sh"
chmod +x "$APP/Contents/Resources/install-addin.sh"
ditto --norsrc --noextattr "$ROOT/r-package" "$APP/Contents/Resources/r-package"
find "$APP/Contents/Resources/r-package" -name .DS_Store -delete
xattr -cr "$APP"
if [[ -n "${CODE_SIGN_IDENTITY:-}" ]]; then
    codesign --force --deep --options runtime --timestamp --sign "$CODE_SIGN_IDENTITY" "$APP"
else
    codesign --force --deep --sign - "$APP"
fi

echo "$APP"
