#!/bin/sh
set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
BUILD_DIR="$ROOT_DIR/build-cmake"
DEST_BIN="/usr/ports/pkg"
JOBS="${JOBS:-$(sysctl -n hw.ncpu 2>/dev/null || getconf _NPROCESSORS_ONLN 2>/dev/null || echo 1)}"

cmake -S "$ROOT_DIR" -B "$BUILD_DIR"
cmake --build "$BUILD_DIR" -j"$JOBS"

BIN_SRC="$BUILD_DIR/tool/pkg/pkg"
if [ ! -x "$BIN_SRC" ]; then
  echo "build succeeded but binary not found: $BIN_SRC" >&2
  exit 1
fi

install -d /usr/ports
install -m 0755 "$BIN_SRC" "$DEST_BIN"

echo "installed: $DEST_BIN"
