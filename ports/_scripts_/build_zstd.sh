#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PREFIX_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
DEPS_DIR="$SCRIPT_DIR/deps"
SRC_DIR="$DEPS_DIR/zstd"
BUILD_DIR="$SCRIPT_DIR/build/zstd"

if ! command -v clang >/dev/null 2>&1; then
  echo "clang not found in PATH" >&2
  exit 1
fi

mkdir -p "$DEPS_DIR" "$BUILD_DIR"

if [ ! -d "$SRC_DIR/.git" ]; then
  git clone --depth 1 https://github.com/facebook/zstd.git "$SRC_DIR"
else
  git -C "$SRC_DIR" fetch --depth 1 origin
  git -C "$SRC_DIR" reset --hard origin/HEAD
fi

cmake -S "$SRC_DIR/build/cmake" -B "$BUILD_DIR" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="$PREFIX_DIR" \
  -DCMAKE_INSTALL_LIBDIR="lib/x86_64" \
  -DBUILD_SHARED_LIBS=OFF \
  -DZSTD_BUILD_PROGRAMS=OFF \
  -DZSTD_BUILD_CONTRIB=OFF \
  -DZSTD_BUILD_TESTS=OFF \
  -DCMAKE_C_COMPILER=clang \
  -DCMAKE_C_FLAGS="-fPIC -O2" \
  -DCMAKE_POSITION_INDEPENDENT_CODE=ON

cmake --build "$BUILD_DIR" --config Release -- -j"$(nproc)"
cmake --install "$BUILD_DIR"
