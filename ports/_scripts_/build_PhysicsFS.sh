#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PREFIX_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
DEPS_DIR="$SCRIPT_DIR/deps"
SRC_DIR="$DEPS_DIR/physfs"
BUILD_DIR="$SCRIPT_DIR/build/physfs"

if ! command -v clang >/dev/null 2>&1; then
  echo "clang not found in PATH" >&2
  exit 1
fi

if ! command -v clang++ >/dev/null 2>&1; then
  echo "clang++ not found in PATH" >&2
  exit 1
fi

mkdir -p "$DEPS_DIR" "$BUILD_DIR"

if [ ! -d "$SRC_DIR/.git" ]; then
  git clone --depth 1 https://github.com/icculus/physfs.git "$SRC_DIR"
else
  git -C "$SRC_DIR" fetch --depth 1 origin
  git -C "$SRC_DIR" reset --hard origin/HEAD
fi

cmake -S "$SRC_DIR" -B "$BUILD_DIR" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="$PREFIX_DIR" \
  -DCMAKE_INSTALL_LIBDIR="lib/x86_64" \
  -DPHYSFS_BUILD_SHARED=OFF \
  -DPHYSFS_BUILD_STATIC=ON \
  -DPHYSFS_BUILD_TEST=OFF \
  -DCMAKE_C_COMPILER=clang \
  -DCMAKE_CXX_COMPILER=clang++ \
  -DCMAKE_CXX_FLAGS="-stdlib=libc++" \
  -DCMAKE_EXE_LINKER_FLAGS="-stdlib=libc++" \
  -DCMAKE_SHARED_LINKER_FLAGS="-stdlib=libc++"

cmake --build "$BUILD_DIR" --config Release -- -j"$(nproc)"
cmake --install "$BUILD_DIR"
