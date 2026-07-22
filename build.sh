#!/bin/sh
# Build the VibePerks Terminal adapter binary.
#
# Local/dev: builds bin/vibeperks-terminal for the host platform (what the shell invokes).
# Release/CI: pass DIST=1 to cross-compile the distribution binaries.
#
# The version is stamped from the VERSION file so there is one source of truth.
set -eu

cd "$(dirname "$0")"

VERSION="v$(head -1 VERSION | tr -d '[:space:]')"

LDFLAGS="-s -w -X main.version=$VERSION"

mkdir -p bin

echo "Building bin/vibeperks-terminal.real $VERSION (host platform)"
( cd src && CGO_ENABLED=0 go build -trimpath -ldflags "$LDFLAGS" -o ../bin/vibeperks-terminal.real . )

if [ "${DIST:-0}" = "1" ]; then
  for pair in darwin/amd64 darwin/arm64 linux/amd64 linux/arm64 windows/amd64; do
    os=${pair%/*}; arch=${pair#*/}
    out="bin/vibeperks-terminal-$os-$arch"
    [ "$os" = "windows" ] && out="$out.exe"
    echo "  building $out"
    ( cd src && CGO_ENABLED=0 GOOS="$os" GOARCH="$arch" \
      go build -trimpath -ldflags "$LDFLAGS" -o "../$out" . )
  done
fi

echo "Done."
