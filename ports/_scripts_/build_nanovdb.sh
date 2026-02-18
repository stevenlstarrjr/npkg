#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PREFIX_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
DEPS_DIR="$SCRIPT_DIR/deps"
SRC_DIR="$DEPS_DIR/openvdb"
NANOVDB_DIR="$SRC_DIR/nanovdb"

mkdir -p "$DEPS_DIR"

if [ ! -d "$SRC_DIR/.git" ]; then
  git clone --depth 1 https://github.com/AcademySoftwareFoundation/openvdb.git "$SRC_DIR"
else
  git -C "$SRC_DIR" fetch --depth 1 origin
  git -C "$SRC_DIR" reset --hard origin/HEAD
fi

if [ ! -d "$NANOVDB_DIR/nanovdb" ]; then
  echo "NanoVDB headers not found at $NANOVDB_DIR/nanovdb" >&2
  exit 1
fi

install -d "$PREFIX_DIR/include/nanovdb"
cp -R "$NANOVDB_DIR/nanovdb/"* "$PREFIX_DIR/include/nanovdb/"
