#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h}"
APP_NAME="ES Status.app"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT/Resources/Info.plist")"
ASSET_NAME="ESStatus-macos-arm64"
ASSET_URL="${ESSTATUS_ASSET_URL:-${RSTATUS_ASSET_URL:-https://github.com/Dev-os-elop/R-status/releases/download/v${VERSION}/${ASSET_NAME}}}"
EXPECTED_SHA256="$(tr -d '[:space:]' < "$ROOT/Resources/ESStatus-macos-arm64.sha256")"
TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/rstatus-install.XXXXXX")"
trap 'rm -rf "$TEMP_DIR"' EXIT

if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "오류: ES Status는 macOS에서만 설치할 수 있습니다." >&2
    exit 1
fi

if [[ "$(uname -m)" != "arm64" && "$(sysctl -in hw.optional.arm64 2>/dev/null || true)" != "1" ]]; then
    echo "오류: 현재 사전 빌드 앱은 Apple Silicon Mac만 지원합니다." >&2
    exit 1
fi

for command_name in R Rscript codesign curl shasum; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
        echo "오류: '$command_name' 명령을 찾을 수 없습니다." >&2
        echo "README의 필수 조건을 확인해 주세요." >&2
        exit 1
    fi
done

if [[ -n "${INSTALL_DIR:-}" ]]; then
    APP_DIR="$INSTALL_DIR"
elif [[ -w /Applications ]]; then
    APP_DIR="/Applications"
else
    APP_DIR="$HOME/Applications"
fi

APP_PATH="$APP_DIR/$APP_NAME"

echo "[1/4] macOS 메뉴바 앱 다운로드"
BINARY="$TEMP_DIR/$ASSET_NAME"
curl --fail --location --retry 3 --progress-bar "$ASSET_URL" --output "$BINARY"
ACTUAL_SHA256="$(shasum -a 256 "$BINARY" | awk '{print $1}')"
if [[ "$ACTUAL_SHA256" != "$EXPECTED_SHA256" ]]; then
    echo "오류: 다운로드한 앱의 SHA-256이 일치하지 않습니다." >&2
    echo "예상: $EXPECTED_SHA256" >&2
    echo "실제: $ACTUAL_SHA256" >&2
    exit 1
fi
chmod +x "$BINARY"
"$ROOT/scripts/assemble-app.sh" "$BINARY"

echo "[2/4] 앱 설치: $APP_PATH"
RUNNING_PIDS=()
if [[ "${ESSTATUS_RUNNING_PID:-}" == <-> ]] && kill -0 "$ESSTATUS_RUNNING_PID" 2>/dev/null; then
    RUNNING_PIDS+=("$ESSTATUS_RUNNING_PID")
elif [[ "${RSTATUS_RUNNING_PID:-}" == <-> ]] && kill -0 "$RSTATUS_RUNNING_PID" 2>/dev/null; then
    RUNNING_PIDS+=("$RSTATUS_RUNNING_PID")
else
    while IFS= read -r running_pid; do
        [[ -n "$running_pid" ]] && RUNNING_PIDS+=("$running_pid")
    done < <({ pgrep -x ESStatus; pgrep -x RStudioStatus; } 2>/dev/null | sort -u || true)
fi

# Remove bundles installed under the former product name so users never end up
# with both ES Status and RStudio Status in Applications or LaunchServices.
LEGACY_APP_PATHS=(
    "$APP_DIR/RStudio Status.app"
    "/Applications/RStudio Status.app"
    "$HOME/Applications/RStudio Status.app"
)
for legacy_app_path in "${LEGACY_APP_PATHS[@]}"; do
    if [[ "$legacy_app_path" != "$APP_PATH" && -d "$legacy_app_path" ]]; then
        "$LSREGISTER" -u "$legacy_app_path" 2>/dev/null || true
        rm -rf "$legacy_app_path"
    fi
done

if [[ -d "$APP_PATH" ]]; then
    "$LSREGISTER" -u "$APP_PATH" 2>/dev/null || true
    # Replace the entire bundle instead of merging into it. This removes stale
    # icon resources from older versions and forces LaunchServices to register
    # the current Cat Original icon filename.
    rm -rf "$APP_PATH"
fi
mkdir -p "$APP_DIR"
ditto "$ROOT/dist/$APP_NAME" "$APP_PATH"
xattr -cr "$APP_PATH"
codesign --force --deep --sign - "$APP_PATH"
codesign --verify --deep "$APP_PATH"
"$LSREGISTER" -f "$APP_PATH"
"$LSREGISTER" -u "$ROOT/dist/$APP_NAME" 2>/dev/null || true

echo "[3/4] RStudio Addin 설치"
"$ROOT/scripts/install-r-package.sh"
defaults write io.github.ljwook92.esstatus installedAddinVersion -string "$VERSION"
defaults write io.github.ljwook92.esstatus addinPromptedVersion -string "$VERSION"

echo "[4/4] 앱 재실행 예약"
# Remove one-shot restart jobs left by older updater versions before creating
# the new one. The normal login item is intentionally not touched.
while IFS= read -r restart_label; do
    [[ -n "$restart_label" ]] && /bin/launchctl remove "$restart_label" 2>/dev/null || true
done < <(/bin/launchctl list 2>/dev/null | /usr/bin/awk '$3 ~ /^io.github.ljwook92.(rstatus|esstatus).restart\./ {print $3}')
RESTART_LABEL="io.github.ljwook92.esstatus.restart.$$.$RANDOM"
/bin/launchctl submit -l "$RESTART_LABEL" -- \
    /bin/zsh "$ROOT/scripts/restart-app.sh" "$RESTART_LABEL" "$APP_PATH" "${RUNNING_PIDS[@]}"

echo
echo "설치가 완료되었습니다."
echo "앱: $APP_PATH"
echo "RStudio를 다시 시작한 뒤 Addins 메뉴를 확인하세요."
echo "첫 실행 시 macOS 알림 권한을 허용해 주세요."
