#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PREFIX_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
DEPS_DIR="$SCRIPT_DIR/deps"
SRC_DIR="$DEPS_DIR/luajit2"

if ! command -v clang >/dev/null 2>&1; then
  echo "clang not found in PATH" >&2
  exit 1
fi

mkdir -p "$DEPS_DIR"

if [ ! -d "$SRC_DIR/.git" ]; then
  git clone --depth 1 https://github.com/openresty/luajit2.git "$SRC_DIR"
else
  git -C "$SRC_DIR" fetch --depth 1 origin
  git -C "$SRC_DIR" reset --hard origin/HEAD
fi

cd "$SRC_DIR"

make -j"$(nproc)" CC=clang
make install PREFIX="$PREFIX_DIR"
