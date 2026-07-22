#!/bin/sh
# VibePerks Terminal uninstaller (macOS/Linux).
#
# Removes the managed block that install.sh added to your shell rc, so the sponsor
# line and Enter hook stop loading in new shells. Your local config/cache in
# ~/.vibeperks is left untouched; delete that directory yourself if you also want to
# remove your device token and cached ad.
set -eu

cd "$(dirname "$0")"
MARK_BEGIN="# >>> vibeperks-terminal >>>"
MARK_END="# <<< vibeperks-terminal <<<"

# Cover every rc install.sh may have written to.
for RC in "$HOME/.zshrc" "$HOME/.config/fish/config.fish" "$HOME/.bashrc"; do
  [ -f "$RC" ] || continue
  if grep -qF "$MARK_BEGIN" "$RC"; then
    tmp="$(mktemp)"
    awk -v b="$MARK_BEGIN" -v e="$MARK_END" '
      $0==b {skip=1} skip && $0==e {skip=0; next} !skip {print}
    ' "$RC" >"$tmp"
    mv "$tmp" "$RC"
    echo "Removed the VibePerks block from $RC"
  fi
done

echo "Uninstalled. Open a new shell to apply. Delete ~/.vibeperks to also remove your token and cache."
