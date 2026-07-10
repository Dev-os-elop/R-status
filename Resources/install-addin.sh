#!/bin/zsh
set -euo pipefail

RESOURCES="${0:A:h}"
R_PACKAGE="$RESOURCES/r-package"

find_r_binary() {
    local name="$1"
    local candidate
    for candidate in \
        "/usr/local/bin/$name" \
        "/opt/homebrew/bin/$name" \
        "/Library/Frameworks/R.framework/Resources/bin/$name" \
        "/Library/Frameworks/R.framework/Versions/Current/Resources/bin/$name"; do
        if [[ -x "$candidate" ]]; then
            echo "$candidate"
            return 0
        fi
    done
    return 1
}

if [[ ! -d "$R_PACKAGE" ]]; then
    echo "Bundled R package not found: $R_PACKAGE" >&2
    exit 1
fi

R_BIN="${R_BIN:-$(find_r_binary R || true)}"
RSCRIPT_BIN="${RSCRIPT_BIN:-$(find_r_binary Rscript || true)}"

if [[ -z "$R_BIN" || -z "$RSCRIPT_BIN" ]]; then
    echo "R was not found. Install R and RStudio Desktop, then try again." >&2
    exit 1
fi

R_USER_LIBRARY="$($RSCRIPT_BIN --vanilla -e 'cat(path.expand(Sys.getenv("R_LIBS_USER")))')"
mkdir -p "$R_USER_LIBRARY"

"$RSCRIPT_BIN" --vanilla - "$R_USER_LIBRARY" <<'RSCRIPT'
args <- commandArgs(trailingOnly = TRUE)
user_library <- args[[1L]]
dependencies <- c("rstudioapi", "later")
missing <- dependencies[!vapply(
  dependencies,
  requireNamespace,
  logical(1),
  quietly = TRUE,
  lib.loc = c(user_library, .libPaths())
)]
if (length(missing)) {
  message("Installing required R packages: ", paste(missing, collapse = ", "))
  install.packages(missing, lib = user_library, repos = "https://cloud.r-project.org")
}
RSCRIPT

"$R_BIN" CMD INSTALL --library="$R_USER_LIBRARY" "$R_PACKAGE"
echo "RStudio Addin installed in $R_USER_LIBRARY/rstudiostatus"
