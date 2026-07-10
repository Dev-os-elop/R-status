#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT/Resources/Info.plist")"
RELEASE_REPO="${RELEASE_REPO:-Ljwook92/R-status-releases}"
DMG="$ROOT/release/RStudio-Status-$VERSION.dmg"
CHECKSUM="$DMG.sha256"

if ! command -v gh >/dev/null 2>&1; then
    echo "오류: GitHub CLI(gh)가 필요합니다." >&2
    exit 1
fi

if [[ ! -f "$DMG" || ! -f "$CHECKSUM" ]]; then
    echo "오류: 릴리스 파일이 없습니다. 먼저 make release를 실행하세요." >&2
    exit 1
fi

gh repo view "$RELEASE_REPO" >/dev/null
gh release create "v$VERSION" \
    "$DMG" \
    "$CHECKSUM" \
    --repo "$RELEASE_REPO" \
    --title "RStudio Status v$VERSION" \
    --generate-notes

echo "Published: https://github.com/$RELEASE_REPO/releases/tag/v$VERSION"
