#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PREFIX_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
DEPS_DIR="$SCRIPT_DIR/deps"
SRC_DIR="$DEPS_DIR/filament"
BUILD_DIR="$SCRIPT_DIR/build/filament"

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
  git clone --depth 1 https://github.com/google/filament.git "$SRC_DIR"
else
  git -C "$SRC_DIR" fetch --depth 1 origin
  git -C "$SRC_DIR" reset --hard origin/HEAD
fi

cmake -S "$SRC_DIR" -B "$BUILD_DIR" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="$PREFIX_DIR" \
  -DCMAKE_INSTALL_LIBDIR="lib/x86_64" \
  -DBUILD_SHARED_LIBS=OFF \
  -DFILAMENT_ENABLE_JAVA=OFF \
  -DFILAMENT_SKIP_SAMPLES=ON \
  -DFILAMENT_SKIP_SDL2=ON \
  -DFILAMENT_SUPPORTS_VULKAN=ON \
  -DFILAMENT_SUPPORTS_OPENGL=ON \
  -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
  -DCMAKE_C_COMPILER=clang \
  -DCMAKE_CXX_COMPILER=clang++ \
  -DCMAKE_C_FLAGS="-fPIC" \
  -DCMAKE_CXX_FLAGS="-stdlib=libc++ -fPIC" \
  -DCMAKE_EXE_LINKER_FLAGS="-stdlib=libc++" \
  -DCMAKE_SHARED_LINKER_FLAGS="-stdlib=libc++"

cmake --build "$BUILD_DIR" --config Release -- -j"$(nproc)"
cmake --install "$BUILD_DIR"
