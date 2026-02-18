#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PREFIX_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
DEPS_DIR="$SCRIPT_DIR/deps"
SRC_DIR="$DEPS_DIR/miniaudio"

mkdir -p "$DEPS_DIR"

if [ ! -d "$SRC_DIR/.git" ]; then
  git clone --depth 1 https://github.com/mackron/miniaudio.git "$SRC_DIR"
else
  git -C "$SRC_DIR" fetch --depth 1 origin
  git -C "$SRC_DIR" reset --hard origin/HEAD
fi

install -d "$PREFIX_DIR/include/miniaudio"
install -m 0644 "$SRC_DIR/miniaudio.h" "$PREFIX_DIR/include/miniaudio/miniaudio.h"
