#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PREFIX_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
DEPS_DIR="$SCRIPT_DIR/deps"
SRC_DIR="$DEPS_DIR/lexbor"
BUILD_DIR="$SCRIPT_DIR/build_lexbor"

JOBS="${JOBS:-$(nproc)}"
LEXBOR_TAG="${LEXBOR_TAG:-v2.5.0}"

if ! command -v git >/dev/null 2>&1; then
  echo "git not found in PATH" >&2
  exit 1
fi
if ! command -v cmake >/dev/null 2>&1; then
  echo "cmake not found in PATH" >&2
  exit 1
fi
if ! command -v clang >/dev/null 2>&1 || ! command -v clang++ >/dev/null 2>&1; then
  echo "clang/clang++ not found in PATH" >&2
  exit 1
fi

mkdir -p "$DEPS_DIR"

if [ ! -d "$SRC_DIR/.git" ]; then
  git clone --depth 1 --branch "$LEXBOR_TAG" https://github.com/lexbor/lexbor.git "$SRC_DIR"
else
  git -C "$SRC_DIR" fetch --depth 1 origin "$LEXBOR_TAG"
  git -C "$SRC_DIR" checkout -q FETCH_HEAD
fi

rm -rf "$BUILD_DIR"
cmake -S "$SRC_DIR" -B "$BUILD_DIR" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_C_COMPILER=clang \
  -DCMAKE_CXX_COMPILER=clang++ \
  -DCMAKE_C_FLAGS="-O2 -fPIC" \
  -DCMAKE_CXX_FLAGS="-O2 -fPIC" \
  -DBUILD_SHARED_LIBS=ON \
  -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
  -DCMAKE_INSTALL_PREFIX="$PREFIX_DIR" \
  -DCMAKE_INSTALL_LIBDIR=lib/x86_64

cmake --build "$BUILD_DIR" -j"$JOBS"
cmake --install "$BUILD_DIR"

echo "=== lexbor installed to $PREFIX_DIR ==="
