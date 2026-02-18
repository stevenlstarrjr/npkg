#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PREFIX_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
DEPS_DIR="$SCRIPT_DIR/deps"
SRC_DIR="$DEPS_DIR/sqlite"

if ! command -v clang >/dev/null 2>&1; then
  echo "clang not found in PATH" >&2
  exit 1
fi

mkdir -p "$DEPS_DIR"

if [ ! -d "$SRC_DIR/.git" ]; then
  git clone --depth 1 https://github.com/sqlite/sqlite.git "$SRC_DIR"
else
  git -C "$SRC_DIR" fetch --depth 1 origin
  git -C "$SRC_DIR" reset --hard origin/HEAD
fi

cd "$SRC_DIR"

./configure \
  CC=clang \
  CFLAGS="-O2 -fPIC" \
  --prefix="$PREFIX_DIR" \
  --libdir="$PREFIX_DIR/lib/x86_64" \
  --disable-tcl \
  --enable-static \
  --disable-shared

make -j"$(nproc)"
make install
