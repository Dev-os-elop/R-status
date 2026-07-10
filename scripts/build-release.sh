#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT/Resources/Info.plist")"
APP="$ROOT/dist/ES Status.app"
RELEASE_DIR="$ROOT/release"
DMG="$RELEASE_DIR/ES-Status-$VERSION.dmg"
CHECKSUM="$DMG.sha256"
STAGING="$(mktemp -d "${TMPDIR:-/tmp}/rstatus-release.XXXXXX")"
trap 'rm -rf "$STAGING"' EXIT

"$ROOT/scripts/build-app.sh"

if [[ ! -d "$APP/Contents/Resources/r-package" || ! -f "$APP/Contents/Resources/install-addin.sh" ]]; then
    echo "오류: 앱 번들에 RStudio Addin 설치 리소스가 없습니다." >&2
    exit 1
fi

mkdir -p "$RELEASE_DIR"
rm -f "$DMG" "$CHECKSUM"

ditto --norsrc --noextattr "$APP" "$STAGING/ES Status.app"
ln -s /Applications "$STAGING/Applications"
cp "$ROOT/distribution/INSTALL.txt" "$STAGING/INSTALL.txt"

hdiutil create \
    -volname "ES Status" \
    -srcfolder "$STAGING" \
    -format UDZO \
    -ov \
    "$DMG"

if [[ -n "${CODE_SIGN_IDENTITY:-}" ]]; then
    codesign --force --timestamp --sign "$CODE_SIGN_IDENTITY" "$DMG"
fi

if [[ -n "${NOTARY_PROFILE:-}" ]]; then
    if [[ -z "${CODE_SIGN_IDENTITY:-}" ]]; then
        echo "오류: 공증에는 CODE_SIGN_IDENTITY가 필요합니다." >&2
        exit 1
    fi
    xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$DMG"
    xcrun stapler validate "$DMG"
fi

cd "$RELEASE_DIR"
shasum -a 256 "${DMG:t}" > "${CHECKSUM:t}"

echo
echo "Release artifact: $DMG"
echo "SHA-256: $CHECKSUM"
if [[ -z "${CODE_SIGN_IDENTITY:-}" ]]; then
    echo "주의: Developer ID 인증서가 없어 ad-hoc 서명으로 빌드했습니다."
    echo "공개 배포 전 DISTRIBUTION.md의 서명·공증 절차를 확인하세요."
fi
