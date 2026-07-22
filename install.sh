#!/bin/sh
# VibePerks Terminal installer (macOS/Linux).
#
# Builds the adapter binary and adds a managed block to your shell rc that sources the
# VibePerks Terminal shell integration. Re-running is safe: the managed block is replaced,
# not duplicated.
set -eu

cd "$(dirname "$0")"
ROOT="$(pwd)"
MARK_BEGIN="# >>> vibeperks-terminal >>>"
MARK_END="# <<< vibeperks-terminal <<<"

echo "Preparing the adapter binary..."
# The bin/vibeperks-terminal launcher resolves a runnable binary at first use: it
# downloads the prebuilt binary for this platform from the GitHub Release (and caches
# it), so Go is NOT required. Build now only when Go is available so the first run is
# instant; otherwise the launcher fetches the prebuilt binary the first time the shell
# integration invokes it.
if command -v go >/dev/null 2>&1; then
  sh ./build.sh >/dev/null || echo "Build skipped; the launcher will download a prebuilt binary on first use."
else
  echo "Go not found; the launcher will download a prebuilt binary on first use (no build needed)."
fi

# Pick the rc file and matching integration script for the current shell.
case "${SHELL##*/}" in
  zsh)  RC="$HOME/.zshrc";                       INTEGRATION="scripts/shell-integration.zsh" ;;
  fish) RC="$HOME/.config/fish/config.fish";     INTEGRATION="scripts/shell-integration.fish" ;;
  *)    RC="$HOME/.bashrc";                       INTEGRATION="scripts/shell-integration.bash" ;;
esac

mkdir -p "$(dirname "$RC")"
touch "$RC"

BLOCK="$MARK_BEGIN
export VIBEPERKS_TERMINAL_BIN=\"$ROOT/bin/vibeperks-terminal\"
. \"$ROOT/$INTEGRATION\"
$MARK_END"

# Drop any previous managed block, then append the current one.
tmp="$(mktemp)"
awk -v b="$MARK_BEGIN" -v e="$MARK_END" '
  $0==b {skip=1} skip && $0==e {skip=0; next} !skip {print}
' "$RC" >"$tmp"
printf '%s\n' "$BLOCK" >>"$tmp"
mv "$tmp" "$RC"

# Detect an already-configured device token so re-installs don't nag the user to log in
# again. Mirrors core.ConfigDir(): $VIBEPERKS_HOME overrides ~/.vibeperks.
CONFIG_DIR="${VIBEPERKS_HOME:-$HOME/.vibeperks}"
CONFIG_PATH="$CONFIG_DIR/config.json"
if [ -f "$CONFIG_PATH" ] && grep -q '"device_token"[[:space:]]*:[[:space:]]*"[^"]\{1,\}"' "$CONFIG_PATH"; then
  echo "Installed. Existing device token detected - no login needed. Open a new shell to start."
else
  echo "Installed. Open a new shell, then run: vibeperks-terminal login <device-token>"
fi
